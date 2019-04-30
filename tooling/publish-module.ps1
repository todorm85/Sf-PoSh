Set-Location "$PSScriptRoot\..\"
git clean -xdf
$apiKey = Read-Host -Prompt "API Key: "
$notes = Read-Host -Prompt "Release notes: "
Publish-Module -Name "sf-dev" -NuGetApiKey $apiKey -ReleaseNote $notes -ProjectUri "https://github.com/todorm85/sitefinity-dev-orchestration"