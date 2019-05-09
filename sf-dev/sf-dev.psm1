Using module toko-admin

# declare types - all have to be here at psm file for intellisense, otherwise cannot be exported outside module

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
        sf-show-currentProject -detail -context $this
    }
}

#fluent

class FluentBase {
    [SfProject] hidden $project
    [SfProject] GetProject () {
        if (!$this.project) {
            throw "You must select a project to work with first."
        }

        return $this.project
    }
    [void] SetProject([SfProject]$project) {
        $this.project = $project
    }
}

class ProjectFluent : FluentBase {
    [SolutionFluent] $solution
    [WebAppFluent] $webApp

    ProjectFluent ([SfProject]$project) {
        $this.Init($project)
    }

    [void] Init ([SfProject]$project) {
        $this.SetProject($project)
        $this.solution = [SolutionFluent]::new($project)
        $this.webApp = [WebAppFluent]::new($project)
        set-currentProject -newContext $project -fluentInited
    }

    [void] Select () {
        [SfProject]$selectedSitefinity = prompt-projectSelect -showUnused
        $this.Init($selectedSitefinity)
    }

    [void] Create () {
        $selectedBranch = prompt-predefinedBranchSelect
        $name = $null
        while (!$name) {
            $name = Read-Host -Prompt "Enter name"
        }
        
        [SfProject]$newProject = sf-new-project -displayName $name -customBranch $selectedBranch -noAutoSelect

        $this.Init($newProject)
    }

    [void] Create ([string]$name, [string]$branchPath) {
        [SfProject]$newProject = sf-new-project -displayName $name -customBranch $branchPath -noAutoSelect

        $this.Init($newProject)
    }

    [void] Import ([string]$name, [string]$path) {
        $this.Import($name, $path, $null)
    }

    [void] Import ([string]$name, [string]$path, [bool]$cloneDb) {
        [SfProject]$newProj = sf-import-project -displayName $name -path $path -cloneDb $cloneDb -noAutoSelect

        $this.Init($newProj)
    }

    [void] Clone() {
        [SfProject]$newProj = sf-clone-project -context $this.GetProject() -noAutoSelect
        $this.Init($newProj)
    }
    
    [void] Delete() {
        sf-delete-project -context $this.GetProject() -noPrompt
        $this.Init($null)
    }

    [void] DeleteMany() {
        sf-delete-projects
        [SfProject[]]$sitefinities = @(_sfData-get-allProjects)
        $currentProjectWasDeleted = @($sitefinities | where { $_.id -eq $this.project.id }).Count -eq 0

        if ($currentProjectWasDeleted) {
            $this.Init($null)
        }
    }

    [void] Rename([string]$newName) {
        sf-rename-project -newName $newName -project $this.GetProject()
    }
}

class WebAppFluent : FluentBase {
    WebAppFluent([SfProject]$project) {
        $this.SetProject($project)
    }
    
    [void] OpenWebsite () {
        sf-browse-webSite -project $this.GetProject()
    }

    [void] ResetApp () {
        sf-reset-app -start -project $this.GetProject()
    }

    [void] ResetPool () {
        sf-reset-pool -project $this.GetProject()
    }
}

class SolutionFluent : FluentBase {
    SolutionFluent([SfProject]$project) {
        $this.SetProject($project)
    }

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

Set-Location ${PSScriptRoot}

. "./bootstrap/bootstrap.ps1"

$Global:sf = [ProjectFluent]::new($null)

Export-ModuleMember -Function * -Alias *
