Set-Location "$PSScriptRoot\..\"

$version = Read-Host -Prompt "Version: "

.\new-manifest.ps1 $version

git clean -xdf

$apiKey = Read-Host -Prompt "API Key: "
$notes = Read-Host -Prompt "Release notes: "
Publish-Module -Name "sf-dev" -NuGetApiKey $apiKey -ReleaseNote $notes -ProjectUri "https://github.com/todorm85/sitefinity-dev-orchestration"

.\new-manifest.ps1 $version
