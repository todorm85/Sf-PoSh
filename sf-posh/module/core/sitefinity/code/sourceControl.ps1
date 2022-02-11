function sf-source-undoPendingChanges {
    $context = _source-getValidatedProject
    _runInRootLocation {
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
            _runInRootLocation {
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
    _runInRootLocation {
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

    _runInRootLocation {
        Invoke-Expression -Command "git clone $remotePath $directoryName"
    }
}

function sf-source-getCurrentBranch {
    $context = _source-getValidatedProject
    _runInRootLocation {
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

