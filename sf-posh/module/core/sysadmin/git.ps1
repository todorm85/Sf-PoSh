$Script:branchCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )
        
    _git-ensureLocation
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

    _git-ensureLocation
    $branchExists = git branch | % {$_.Trim().Trim('*').Trim()} | ? {$_ -eq $branch}
    if ($branchExists) {
        $res = git checkout $branch 2>&1
    } else {
        $res = git checkout -b $branch 2>&1
    }
    
    if ($res |? {$_.Exception -and $_.Exception.Message.StartsWith("Switched to")}) {
        $p = sf-PSproject-get
        $p.branch = $branch
        _update-prompt $p
    } else {
        Write-Error "Something went wrong: $res"
    }
}

Register-ArgumentCompleter -CommandName sf-git-checkout -ParameterName branch -ScriptBlock $Script:branchCompleter

function sf-git-getAllLocalBranches {
    param(
        [switch]$skipDefaults
    )
    _git-ensureLocation
    $res = git branch | % {$_.Trim('*').Trim()}
    if ($skipDefaults) {
        $res = $res | ? {$_ -ne 'master' -and $_ -ne "patches"}
    }

    $res
}

function _git-ensureLocation {
    $loc = Get-Location
    $p = sf-PSproject-get
    $projRoot = $p.webAppPath
    if ($p.solutionPath) {
        $projRoot = $p.solutionPath
    }

    if (-not $loc.Path.Contains($projRoot)) {
        throw "You must be in project directory to execute git commands."
    }
}