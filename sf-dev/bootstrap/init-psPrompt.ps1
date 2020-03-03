# https://stackoverflow.com/questions/5725888/windows-powershell-changing-the-command-prompt

function Global:prompt {
    Write-Host "PS $(Get-Location)>" -NoNewline
    Write-Host "$Script:prompt" -ForegroundColor Green -NoNewline
    return " "
}

function _update-prompt {
    _setConsoleTitle
    
    $project = sd-project-getCurrent
    $projectName = if ($project) { $project.displayName } else { '' }
    if ($projectName) {
        $prompt = " [$projectName]"
    } 
    else {
        $prompt = ""
    }

    $Script:prompt = $prompt
}

function _setConsoleTitle {
    $newContext = sd-project-getCurrent
    if ($newContext) {
        $ports = sd-iisSite-getDefaultPort
        if ($newContext.branch) {
            $branch = ($newContext.branch).Split([string[]]("$/CMS/Sitefinity 4.0"), [System.StringSplitOptions]::RemoveEmptyEntries)[0]
        }
        else {
            $branch = '/no branch'
        }

        [System.Console]::Title = "($($newContext.id)) $ports $($newContext.displayName) $branch "
        Set-Location $newContext.webAppPath
    }
    else {
        [System.Console]::Title = ""
    }
}
