#Requires -Version 5.1
#Requires -Modules @{ModuleName = 'SqlServer'; ModuleVersion = '21.1.18179'; MaximumVersion = '21.1.*' }
#Requires -Modules WebAdministration

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

function _getFunctionNames {
    $isDev = $Global:sfposhenv -eq 'dev'
    Get-ChildItem -Path "$PSScriptRoot\core" -File -Recurse | 
    Where-Object { $_.Extension -eq '.ps1' -and ($isDev -or $_.Name -notlike "*.init.ps1") } | 
    Get-Content | Where-Object { $_.contains("function") } | 
    Where-Object { $_ -match "^\s*function\s+?(?<name>[\w-]+?)\s.*$" } | 
    ForEach-Object { $Matches["name"] } | Where-Object { $isDev -or !$_.StartsWith("_") }
}

function _getLoadedModuleVersion {
    Get-Content -Path "$PSScriptRoot\version.txt"
}
