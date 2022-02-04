# https://stackoverflow.com/questions/5725888/windows-powershell-changing-the-command-prompt

function Global:prompt {
    Write-Host "PS $(Get-Location)>" -NoNewline
    Write-Host "$Script:prompt" -ForegroundColor Green -NoNewline
    return " "
}

function _update-prompt {
    param($project)
    
    try {
        _setConsoleTitle $project

        $projectName = if ($project) { $project.displayName } else { '' }
        $gitBranch = $project.branch
        if ($projectName) {
            $prompt = " [$projectName : $gitBranch]"
        }
        else {
            $prompt = ""
        }

        $Script:prompt = $prompt
    }
    catch {
        Write-Error "$_"
    }
}

function _setConsoleTitle {
    param($newContext)

    if ($newContext) {
        if ($newContext.branch) {
            $branch = $newContext.branch
        }
        else {
            $branch = 'No source'
        }

        [System.Console]::Title = "$($newContext.id)|$($newContext.displayName)|$branch"
        if ($newContext -and $newContext.webAppPath -and (Test-Path -Path $newContext.webAppPath)) {
            Set-Location $newContext.webAppPath
        }
    }
    else {
        [System.Console]::Title = ""
    }
}
