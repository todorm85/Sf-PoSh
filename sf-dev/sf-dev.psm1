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
    [SolutionFluent] $solution
    [SfProject] hidden $project

    ProjectFluent ([SfProject]$project) {
        $this.project = $project

        $this.solution = [SolutionFluent]::new($project)
    }

    [ProjectFluent] static Select () {
        sf-select-container
        return $Global:sf
    }

    [ProjectFluent] static Create ([string]$name, [string]$branchPath) {
        sf-new-project -displayName $name -customBranch $branchPath
        return $Global:sf
    }

    [void] static Import ([string]$name, [string]$path) {
        [ProjectFluent]::Import($name, $path, $null)
    }

    [void] static Import ([string]$name, [string]$path, [bool]$cloneDb) {
        sf-import-project -displayName $name -path $path -cloneDb $cloneDb
    }

    [void] Clone() {
        sf-clone-project -context $this.project
    }
    
    [void] Delete() {
        sf-delete-project -context $this.project
    }

    [void] ShowDetails() {
        sf-show-currentProject -detail -context $this.project
    }

    [void] Rename([string]$newName) {
        sf-rename-project -newName $newName -project $this.project
    }

    # shortcuts for more specific functionalities

    [void] Build () {
        $this.solution.Build(3)
    }

    [void] OpenSolution () {
        $this.solution.Open()
    }

    [void] OpenWebsite () {
        sf-browse-webSite -project $this.project
    }

    [void] ResetWebApp () {
        sf-reset-app -start -project $this.project
    }

    [void] ResetAppPool () {
        sf-reset-pool -project $this.project
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

Export-ModuleMember -Function * -Alias *
