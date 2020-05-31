$GLOBAL:sf = [PSCustomObject]@{ }

$Script:moduleUserDir = "$Global:HOME\documents\sf-posh"
if (-not (Test-Path $Script:moduleUserDir)) {
    New-Item -Path $Script:moduleUserDir -ItemType Directory
}

. "$PSScriptRoot\bootstrap\init-config.ps1"
. "$PSScriptRoot\bootstrap\initialize-events.ps1"
. "$PSScriptRoot\bootstrap\init-psPrompt.ps1"
. "$PSScriptRoot\bootstrap\load-scripts.ps1"
. "$PSScriptRoot\bootstrap\run-upgrades.ps1"

Export-ModuleMember -Function *

$current = _getLoadedModuleVersion
$updatesPath = "\\tmitskov\sf-posh"
$latestVersion = Get-ChildItem -Path $updatesPath -Directory | Sort-Object -Property CreationTime | Select -First 1
if ($latestVersion -and (_isFirstVersionLower $current $latestVersion.name)) {
    Remove-Module sf-posh -Force
    $source = $latestVersion.FullName
    Remove-Item "$PSScriptRoot\*" -Force -Recurse
    Copy-Item "$source\*" $PSScriptRoot -Force -Recurse
    Write-Warning "Module updated to latest version. Reloading..."
    Import-Module "$PSScriptRoot\sf-posh.psd1" -Force
}