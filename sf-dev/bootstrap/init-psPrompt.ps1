# https://stackoverflow.com/questions/5725888/windows-powershell-changing-the-command-prompt

function Global:prompt {
    Write-Host "PS $(Get-Location)>" -NoNewline

    $currentContainer = $Script:globalContext.containerName
    $projectName = $Script:globalContext.displayName

    if ($projectName) {
        $prompt = " ["

        if ($currentContainer) {
            $prompt = " [$currentContainer | "
        }

        $prompt = "$prompt$projectName]"
    } 
    else {
        $prompt = ""
    }

    Write-Host "$prompt" -ForegroundColor Green -NoNewline
    return " "
}
