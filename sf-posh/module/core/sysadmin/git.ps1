$Script:branchCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )

    
    $possibleValues = git branch | % {$_.Trim().Trim('*').Trim()}
    if ($wordToComplete) {
        $possibleValues = $possibleValues | Where-Object {
            $_ -like "$wordToComplete*"
        }
    }

    $possibleValues
}

function sf-git-checkout {
    param (
        $branch
    )
    
    $res = git checkout $branch
    if ($res.StartsWith("Switched to")) {
        $p = sf-PSproject-get
        $p.branch = $branch
        _update-prompt $p
    } else {
        $res
    }
}

Register-ArgumentCompleter -CommandName sf-git-checkout -ParameterName branch -ScriptBlock $Script:branchCompleter
