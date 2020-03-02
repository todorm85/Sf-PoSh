Get-Content -Path "$PSScriptRoot/../sf-dev/sf-dev.psd1" |
    ForEach-Object {
        if ($_ -match "ModuleVersion     = '(?<vrsn>.+?)'") {
            $Script:version = $matches["vrsn"]
        }
    }
    
if (!$Script:version) {
    throw 'No module version found.'
}

Set-Location "$PSScriptRoot"

. "./set-exportedFunctions.ps1"
git commit --quiet -a -m "Update before tag"

git tag $Script:version
git push origin --tags

Publish-Module -Name "sf-dev" -NuGetApiKey $Env:NuGetApiKey
