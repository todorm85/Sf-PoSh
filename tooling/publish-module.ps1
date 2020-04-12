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
git commit --quiet -a -m "Update for publishing"

. "./set-exportedFunctions.ps1"
git commit --quiet -a -m "Update exported functions definition"

$res = git tag $Script:version 2>&1
if ($res -and $res.ToString().Contains('fatal')) {
    $response = Read-Host -Prompt "Tag with this version already exists. Continue with publish?"
    if ($response -ne 'y') {
        return
    }
} else {
    git push origin --tags
}

Publish-Module -Name "sf-dev" -NuGetApiKey $Env:NuGetApiKey