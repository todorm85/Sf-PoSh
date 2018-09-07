# https://stackoverflow.com/questions/5725888/windows-powershell-changing-the-command-prompt

function Global:prompt {
    Write-Host "PS $(Get-Location | % {
        $segments = $_.Path.Split('\')
        $segments[$segments.Count -1]
    })>" -NoNewline

    $promptContainer = $Script:globalContext.containerName
    $promptProject = $Script:globalContext.displayName
    $promptId = $Script:globalContext.id

    $ports = @(iis-get-websitePort $Script:globalContext.websiteName)
    
    if ($promptProject) {
        if (-not ([string]::IsNullOrEmpty($promptContainer))) {
            $prompt = " [$promptContainer | "
        }
        else {
            $prompt = " ["
        } 

        $prompt = "$prompt$promptProject | $promptId | $ports]"
    } 
    else {
        $prompt = ""
    }

    Write-Host "$prompt" -ForegroundColor Green -NoNewline
    return " "
}
