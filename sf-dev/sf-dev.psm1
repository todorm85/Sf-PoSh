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

class ProjectFluent : FluentBase {
    ProjectFluent ([SfProject]$project) : base($project) { }

    [void] Select () {
        sf-select-project -showUnused
    }

    [void] Create () {
        $selectedBranch = prompt-predefinedBranchSelect
        $name = $null
        while (!$name) {
            $name = Read-Host -Prompt "Enter name"
        }
        
        sf-new-project -displayName $name -customBranch $selectedBranch
    }

    [void] Create ([string]$name, [string]$branchPath) {
        sf-new-project -displayName $name -customBranch $branchPath
    }

    [void] Import ([string]$name, [string]$path) {
        $this.Import($name, $path, $null)
    }

    [void] Import ([string]$name, [string]$path, [bool]$cloneDb) {
        sf-import-project -displayName $name -path $path -cloneDb $cloneDb
    }

    [void] Clone() {
        sf-clone-project -context $this.GetProject()
    }
    
    [void] Delete() {
        sf-delete-project -context $this.GetProject() -noPrompt
        set-currentProject -newContext $null
    }

    [void] DeleteMany() {
        sf-delete-projects
        [SfProject[]]$sitefinities = @(_sfData-get-allProjects)
        $currentProjectWasDeleted = @($sitefinities | where { $_.id -eq $this.project.id }).Count -eq 0

        if ($currentProjectWasDeleted) {
            $this.Select()
        }
    }

    [void] Rename([string]$newName) {
        sf-rename-project -newName $newName -project $this.GetProject()
    }

    [void] Details() {
        sf-show-currentProject -detail -context $this.GetProject()
    }
}

class IISFluent : FluentBase {
    IISFluent([SfProject]$project) : base($project) { }

    [void] SetupSubApp($subAppName) {
        sf-setup-asSubApp -subAppName $subAppName -project $this.GetProject()
    }

    [void] RemoveSubApp() {
        sf-remove-subApp -project $this.GetProject()
    }

    [void] ResetApplicationPool () {
        sf-reset-pool -project $this.GetProject()
    }

    [void] ResetApplciationThreads() {
        sf-reset-thread -project $this.GetProject()
    }
    
    [void] BrowseWebsite () {
        sf-browse-webSite -project $this.GetProject()
    }
}

class WebAppFluent : FluentBase {
    WebAppFluent([SfProject]$project) : base($project) { }
    
    [void] ResetApp () {
        sf-reset-app -start -project $this.GetProject()
    }

    [void] SaveDbAndConfigs([string]$stateName) {
        sf-new-appState -stateName $stateName -project $this.GetProject()
    }

    [void] SaveDbAndConfigs() {
        $this.SaveDbAndConfigs($null)
    }

    [void] RestoreDbAndConfigs([string]$stateName) {
        sf-restore-appState -stateName $stateName -project $this.GetProject()
    }

    [void] RestoreDbAndConfigs() {
        $this.RestoreDbAndConfigs($null)
    }
}

class SolutionFluent : FluentBase {
    SolutionFluent([SfProject]$project) : base($project) { }

    [void] Build () {
        $this.Build(3)
    }

    [void] Build ([int]$retryCount) {
        sf-build-solution -retryCount $retryCount -project $this.GetProject()
    }

    [void] ReBuild ([int]$retryCount) {
        sf-rebuild-solution -retryCount $retryCount -project $this.GetProject()
    }

    [void] CleanPackages () {
        sf-clean-packages -project $this.GetProject()
    }
    
    [void] Clean () {
        sf-clean-solution -project $this.GetProject()
    }

    [void] Open () {
        sf-open-solution -project $this.GetProject()
    }
}

# module startup

. "$PSScriptRoot/bootstrap/bootstrap.ps1"
$Global:sf = [MasterFluent]::new($null)

Export-ModuleMember -Function * -Alias *
