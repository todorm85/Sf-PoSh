function sf-source-undoPendingChanges {
    $context = _source-getValidatedProject
    InLocationScope $context.solutionPath {
        Invoke-Expression -Command "git restore *"
    }
}

function sf-source-hasPendingChanges {
    param(
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project
    )
    
    process {
        Run-InFunctionAcceptingProjectFromPipeline {
            param($project)
            InLocationScope $project.solutionPath {
                !(!(Invoke-Expression -Command "git status" | ? { $_ -contains "nothing to commit, working tree clean"}))
            }
        }
    }
}

function _source-getValidatedProject {
    [OutputType([SfProject])]
    param()

    [SfProject]$context = sf-PSproject-get
    $solutionPath = $context.solutionPath
    if (!$solutionPath -or !(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

    $context
}

function sf-source-getLatestChanges {

    $context = _source-getValidatedProject
    $solutionPath = $context.solutionPath
    InLocationScope $solutionPath {
        Invoke-Expression -Command "git pull"
    }

    $context.lastGetLatest = [System.DateTime]::Now
    sf-PSproject-save $context
}

function sf-source-new {
    param (
        $remotePath,
        $localPath,
        $directoryName
    )

    InLocationScope $localPath {
        Invoke-Expression -Command "git clone $remotePath $directoryName"
    }
}

function InLocationScope {
    param (
        $location,
        $script
    )
    
    if (!(Test-Path $location)) {
        throw "Invalid local path."
    }

    $originalLocation = Get-Location
    Set-Location $location
    try {
        Invoke-Command -ScriptBlock $script
    }
    finally {
        Set-Location $originalLocation
    }

}

function sf-source-getCurrentBranch {
    $context = _source-getValidatedProject
    InLocationScope $context.solutionPath {
        & git branch | ? {$_.StartsWith("*")} | % {$_.Split(' ')[1]}
    }
}

function sf-source-hasSourceControl {
    try {
        $context = _source-getValidatedProject
    }
    catch {
        return $false        
    }
    
    Test-Path "$($context.solutionPath)\.git"
}