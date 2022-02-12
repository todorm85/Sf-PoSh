$Script:branchCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )
        
    _runInRootLocation {
        $possibleValues = git branch | % { $_.Trim().Trim('*').Trim() }
        if ($wordToComplete) {
            $possibleValues = $possibleValues | Where-Object {
                $_ -like "$wordToComplete*"
            }
        }

        $possibleValues
    }
}

function git-checkout {
    param (
        $branch
    )

    _runInRootLocation {
        $branchExists = git branch | % { $_.Trim().Trim('*').Trim() } | ? { $_ -eq $branch }
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

Register-ArgumentCompleter -CommandName git-checkout -ParameterName branch -ScriptBlock $Script:branchCompleter

function git-getAllLocalBranches {
    param(
        [switch]$skipDefaults
    )
    
    _runInRootLocation {
        $res = git branch | % { $_.Trim('*').Trim() }
        if ($skipDefaults) {
            $res = $res | ? { $_ -ne 'master' -and $_ -ne "patches" }
        }
        
        $res
    }
}

function git-getCurrentBranch {
    $res = git branch 2>&1
    if (!$res.Exception) {
        $res | ? { $_.StartsWith("*") } | % { $_.Split(' ')[1] }
    }
}