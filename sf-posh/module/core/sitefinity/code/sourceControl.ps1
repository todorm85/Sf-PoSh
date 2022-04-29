function sf-git-isClean {
    param(
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project
    )
    
    process {
        Run-InFunctionAcceptingProjectFromPipeline {
            param($project)
            RunInRootLocation {
                !(!(Invoke-Expression -Command "git status" | ? { $_ -contains "nothing to commit, working tree clean" }))
            }
        }
    }
}

function sf-git-getCurrentBranch {
    RunInRootLocation {
        $res = git-getCurrentBranch
        if (!$res.StartsWith("fatal")) {
            $res
        }
    }
}

function sf-git-isEnabled {
    RunInRootLocation {
        Test-Path ".\.git"
    }
}

function sf-git-resetAllChanges {
    RunInRootLocation {
        git-resetAllChanges
    }
}

$Script:branchCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )
    RunInRootLocation {
        git-completeBranchName $wordToComplete
    }
}

function sf-git-checkout {
    param (
        $branch
    )

    RunInRootLocation {
        $branchExists = git-getAllBranches | ? { $_ -eq $branch }
        if ($branchExists) {
            $res = git checkout $branch 2>&1
        }
        else {
            $res = git checkout -b $branch 2>&1
        }
        
        if ($res | ? { $_.Exception -and $_.Exception.Message.StartsWith("Switched to") }) {
            $p = sf-project-get
            $p.branch = $branch
            _update-prompt $p
        }
        else {
            Write-Error "Something went wrong: $res"
        }
    }
}
