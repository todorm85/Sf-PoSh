Using module toko-admin

# declare types - all have to be here at psm file to be able to export the types to be used outside the module. (also needed for intellisense in editors)

class Config {
    [string]$dataPath
    [string]$idPrefix
    [string]$projectsDirectory
    [string]$browserPath
    [string]$vsPath
    [string]$msBuildPath
    [string]$tfsServerName
    [string]$defaultUser
    [string]$defaultPassword
    [string]$sqlServerInstance
    [string]$sqlUser
    [string]$sqlPass
    [string[]]$predefinedBranches
}

class SfProject {
    [string]$id
    [string]$displayName
    [string]$solutionPath
    [string]$webAppPath
    [string]$websiteName

    #needed for performance when selecting sitefinities
    [string]$branch
    [string]$description
    [string]$containerName
    [string]$lastGetLatest

    SfProject() { }

    SfProject($id, $displayName) {
        $this.id = $id;
        $this.displayName = $displayName;
    }

    [void] Details() {
        sf-show-currentProject -context $this
    }
}

#fluent

class FluentBase {
    [SfProject] hidden $_project
    [SfProject] hidden GetProject () {
        if (!$this._project) {
            throw "You must select a project to work with first."
        }

        return $this._project
    }

    FluentBase([SfProject]$project) {
        $this._project = $project
    }

    # hide object methods from fluent intellisense

    [string] hidden ToString() { return ([object]$this).ToString() }

    [int] hidden GetHashCode() { return ([object]$this).GetHashCode() }

    [bool] hidden Equals([object]$obj) { return ([object]$this).Equals($obj) }

    [type] hidden GetType() { return ([object]$this).GetType() }
}

class MasterFluent : FluentBase {
    [SolutionFluent] $solution
    [WebAppFluent] $webApp
    [IISFluent] $IIS
    [ProjectFluent] $project

    MasterFluent ([SfProject]$project) : base($project) {
        $this.solution = [SolutionFluent]::new($project)
        $this.webApp = [WebAppFluent]::new($project)
        $this.IIS = [IISFluent]::new($project)
        $this.project = [ProjectFluent]::new($project)
        set-currentProject -newContext $project -fluentInited
    }
}

# class::Project operations
class ProjectFluent : FluentBase {
    ProjectFluent ([SfProject]$project) : base($project) { }

    # ::Prompts the user to select a project to work with from previously created or imported.
    [void] Select () {
        sf-select-project -showUnused
    }

    # ::Use to create new projects. The user will be prompted to select branch from configured ones and name for the project
    [void] Create () {
        $selectedBranch = prompt-predefinedBranchSelect
        $name = $null
        while (!$name) {
            $name = Read-Host -Prompt "Enter name"
        }
        
        sf-new-project -displayName $name -customBranch $selectedBranch
    }

    # ::Use to create new projects. $branchPath - the TFS branch path to the source
    [void] Create ([string]$name, [string]$branchPath) {
        sf-new-project -displayName $name -customBranch $branchPath
    }

    # ::Use to import existing sitefinity projects to be managed by the tool. $name - the name of the imported project. $path - the directory of the Sitefinity web app
    [void] Import ([string]$name, [string]$path) {
        sf-import-project -displayName $name -path $path
    }

    # ::Use to clone the current project. Will create a copy of everything - site, database and map into a new workspace
    [void] Clone() {
        sf-clone-project -context $this.GetProject()
    }
    
    # ::Delete the current project
    [void] Delete() {
        sf-delete-project -context $this.GetProject() -noPrompt
        set-currentProject -newContext $null
    }

    # ::Batch delete projects
    [void] DeleteMany() {
        sf-delete-projects
        [SfProject[]]$sitefinities = @(_sfData-get-allProjects)
        $currentProjectWasDeleted = @($sitefinities | where { $_.id -eq $this.project.id }).Count -eq 0

        if ($currentProjectWasDeleted) {
            $this.Select()
        }
    }

    # ::Rename the current project
    [void] Rename([string]$newName) {
        sf-rename-project -newName $newName -project $this.GetProject()
    }

    # ::Display details about the current project
    [void] Details() {
        sf-show-currentProject -detail -context $this.GetProject()
    }
}

# class::IIS operations
class IISFluent : FluentBase {
    IISFluent([SfProject]$project) : base($project) { }

    # ::Setups the current project as a sub application in IIS
    [void] SetupSubApp($subAppName) {
        sf-setup-asSubApp -subAppName $subAppName -project $this.GetProject()
    }

    # ::Reverts the sub application mode in IIS of the current project if it was enabled
    [void] RemoveSubApp() {
        sf-remove-subApp -project $this.GetProject()
    }

    # ::Resets the website ApplicationPool
    [void] ResetApplicationPool () {
        sf-reset-pool -project $this.GetProject()
    }

    # ::Resets just the threads of the website application but leaves the ApplicationPool intact, useful if you need to restart hte app domain bu leave the debugger attached for startup debugging
    [void] ResetApplciationThreads() {
        sf-reset-thread -project $this.GetProject()
    }
    
    # ::Opens the configured web browser with the url of the project
    [void] BrowseWebsite () {
        sf-browse-webSite -project $this.GetProject()
    }
}

# class::Web Application operations
class WebAppFluent : FluentBase {
    WebAppFluent([SfProject]$project) : base($project) { }
    
    # ::Resets and reinitializes the web application. This will delete database and restore AppData folder to original state, before initiating a Sitefinity startup
    [void] ResetApp () {
        $this.ResetApp($false)
    }

    # ::Resets and reinitializes the web application. This will delete database and restore AppData folder to original state, before initiating a Sitefinity startup. Params: $force - forces the cleanup of App_Data folder - kills locking processes
    [void] ResetApp ([bool]$force) {
        sf-reset-app -start -project $this.GetProject() -force:$force
    }

    # ::Saves the current web application AppData and Database state for later restore. Useful when debugging tests that change the state of the system. Ex. switch from single to multilingual or delete some content items etc...
    [void] SaveDbAndConfigs([string]$stateName) {
        sf-new-appState -stateName $stateName -project $this.GetProject()
    }

    # ::Saves the current web application AppData and Database state for later restore. Useful when debugging tests that change the state of the system. Ex. switch from single to multilingual or delete some content items etc...
    [void] SaveDbAndConfigs() {
        $this.SaveDbAndConfigs($null)
    }

    # ::Restores previously saved database and AppData folder
    [void] RestoreDbAndConfigs([string]$stateName) {
        sf-restore-appState -stateName $stateName -project $this.GetProject()
    }

    # ::Restores previously saved database and AppData folder
    [void] RestoreDbAndConfigs() {
        $this.RestoreDbAndConfigs($null)
    }
}

# class::Solution operations
class SolutionFluent : FluentBase {
    SolutionFluent([SfProject]$project) : base($project) { }

    # ::Builds the solution with 3 retries. Also disables stylecop check for faster build. Uses msbuild configured for multi threaded building.
    [void] Build () {
        $this.Build(3)
    }

    # ::Builds the solution with given retries count. Also disables stylecop check for faster build. Uses msbuild configured for multi threaded building.
    [void] Build ([int]$retryCount) {
        sf-build-solution -retryCount $retryCount -project $this.GetProject()
    }

    # ::Performs a hard clean of the project before building. Deletes all bin and obj folders from all projects
    [void] ReBuild ([int]$retryCount) {
        sf-rebuild-solution -retryCount $retryCount -project $this.GetProject()
    }

    # ::Cleans downloaded packages for solution
    [void] CleanPackages () {
        sf-clean-packages -project $this.GetProject()
    }
    
    # ::Performs a hard delete of all bins and objs
    [void] Clean () {
        sf-clean-solution -project $this.GetProject()
    }

    # ::Opens the solution in the configured editor of the tool config
    [void] Open () {
        sf-open-solution -project $this.GetProject()
    }
}

# module startup

. "$PSScriptRoot/bootstrap/bootstrap.ps1"
$Global:sf = [MasterFluent]::new($null)

Export-ModuleMember -Function * -Alias *
