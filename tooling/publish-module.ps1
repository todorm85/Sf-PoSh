Set-Location "$PSScriptRoot"
. "./docs-generator.ps1"
git commit --quiet -a -m "Update docs"

Publish-Module -Name "sf-dev" -NuGetApiKey $Env:NuGetApiKey
