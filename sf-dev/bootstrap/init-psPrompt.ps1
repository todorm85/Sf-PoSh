# https://stackoverflow.com/questions/5725888/windows-powershell-changing-the-command-prompt

function Global:prompt {
    Write-Host "PS $(Get-Location)>" -NoNewline
    Write-Host "$Script:prompt" -ForegroundColor Green -NoNewline
    return " "
}

function Set-Prompt {
    param (
        [SfProject]$project
    )

    $projectName = $project.displayName
    if ($projectName) {
        $prompt = " [$projectName]"
    } 
    else {
        $prompt = ""
    }

    $Script:prompt = $prompt
}