Param(
    [Parameter(Mandatory = $true)][string]$version
)

Set-Location "$PSScriptRoot"
. "./docs-generator.ps1"
git commit --quiet -a -m "Update docs"

git tag $version

Publish-Module -Name "sf-dev" -NuGetApiKey $Env:NuGetApiKey
