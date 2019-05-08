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
}

#fluent
# no intellisense when inheritance

function _set-fluent {
    $proj = _get-selectedProject
    $Global:sf = [ProjectFluent]::new($proj)
}

class ProjectFluent {
    [SolutionFluent] hidden $solution
    [SfProject] hidden $project

    [SfProject] hidden GetProject () {
        if (!$this.project) {
            throw "You must select a project to work with first."
        }

        return $this.project
    }

    ProjectFluent() {}

    ProjectFluent ([SfProject]$project) {
        $this.Initialize($project)
    }

    [void] hidden Initialize ([SfProject]$project) {
        $this.project = $project

        $this.solution = [SolutionFluent]::new($project)
    }

    [SolutionFluent] Solution() {
        if (!$this.solution) {
            throw "Solution facade not initialized. Perhaps no project selected?"
        }

        return $this.solution
    }

    [void] Select () {
        sf-select-project
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
        sf-delete-project -context $this.GetProject()
    }

    [void] ShowDetails() {
        sf-show-currentProject -detail -context $this.GetProject()
    }

    [void] Rename([string]$newName) {
        sf-rename-project -newName $newName -project $this.GetProject()
    }

    # shortcuts for more specific functionalities

    [void] Build () {
        $this.Solution().Build(3)
    }

    [void] OpenSolution () {
        $this.Solution().Open()
    }

    [void] OpenWebsite () {
        sf-browse-webSite -project $this.GetProject()
    }

    [void] ResetWebApp () {
        sf-reset-app -start -project $this.GetProject()
    }

    [void] ResetAppPool () {
        sf-reset-pool -project $this.GetProject()
    }
}

class SolutionFluent {
    [SfProject] hidden $project
    
    SolutionFluent([SfProject]$project) {
        $this.project = $project
    }

    [void] Build ([int]$retryCount) {
        sf-build-solution -retryCount $retryCount -project $this.project
    }

    [void] ReBuild ([int]$retryCount) {
        sf-rebuild-solution -retryCount $retryCount -project $this.project
    }

    [void] CleanPackages () {
        sf-clean-packages -project $this.project
    }
    
    [void] Clean () {
        sf-clean-solution -project $this.project
    }

    [void] Clean ([bool]$cleanPackages) {
        sf-clean-solution -cleanPackages $cleanPackages -project $this.project
    }

    [void] Open () {
        sf-open-solution -project $this.project
    }
}

# module startup

Set-Location ${PSScriptRoot}

. "./bootstrap/bootstrap.ps1"

$Global:sf = [ProjectFluent]::new()

Export-ModuleMember -Function * -Alias *
