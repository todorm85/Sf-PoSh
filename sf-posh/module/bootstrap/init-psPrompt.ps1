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
        if ($projectName) {
            $prompt = " [$projectName]"
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
            $branch = ($newContext.branch).Split([string[]]("$/CMS/Sitefinity 4.0"), [System.StringSplitOptions]::RemoveEmptyEntries)[0]
        }
        else {
            $branch = 'No TFS'
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
