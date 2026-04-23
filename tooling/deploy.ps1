. .\constants.ps1

# Update module definitions before bundling
& "$PSScriptRoot\sf-module-updateDefinitions.ps1"

$moduleName = "sf-posh"
$releaseDir = "$PSScriptRoot\..\release"
$targetDir = if ($env:SF_POSH_MODULE_PATH) { $env:SF_POSH_MODULE_PATH } else { $releaseDir }
$targetDir = Join-Path $targetDir $moduleName

if (Test-Path $targetDir) {
    Remove-Item -Path $targetDir -Recurse -Force
}

New-Item -Path $targetDir -ItemType Directory -Force | Out-Null

$itemsToCopy = @(
    "sf-posh.psd1"
    "sf-posh.psm1"
    "bootstrap"
    "core"
)

foreach ($item in $itemsToCopy) {
    $source = Join-Path $sfPoshDevPath $item
    $destination = Join-Path $targetDir $item
    if (Test-Path $source -PathType Container) {
        Copy-Item -Path $source -Destination $destination -Recurse -Force
    } else {
        Copy-Item -Path $source -Destination $destination -Force
    }
}

Write-Host "Module deployed to $targetDir"
