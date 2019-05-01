Set-Location "$PSScriptRoot\..\"

git clean -xdf

$apiKey = Read-Host -Prompt "API Key: "
Publish-Module -Name "sf-dev" -NuGetApiKey $apiKey

& "$PSScriptRoot\new-devManifest.ps1"
