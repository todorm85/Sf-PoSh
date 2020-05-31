$version = Get-Content "$PSScriptRoot\..\sf-posh\version.txt"

if (!$version) {
    throw 'No module version found.'
}

Set-Location "$PSScriptRoot"
git commit --quiet -a -m "Update for publishing"

. "./set-exportedFunctions.ps1"
git commit --quiet -a -m "Update exported functions definition"

$res = git tag $version 2>&1
if ($res -and $res.ToString().Contains('fatal')) {
    $response = Read-Host -Prompt "Tag with this version already exists. Continue with publish?"
    if ($response -ne 'y') {
        return
    }
} else {
    git push origin --tags
}

# Publish-Module -Name "sf-posh" -NuGetApiKey $Env:NuGetApiKey
# Copy-SfToLive
$destination = "$PSScriptRoot\..\dist\$version"
New-Item $destination -Force -ItemType Directory > $null
Copy-Item "$PSScriptRoot\..\sf-posh\*" $destination -Force -Recurse
