#Requires -Version 5.1
#Requires -Modules @{ModuleName = 'SqlServer'; ModuleVersion = '21.1.18179'; MaximumVersion = '21.1.*' }
#Requires -Modules WebAdministration

$GLOBAL:sf = [PSCustomObject]@{ }

Add-Member -InputObject $GLOBAL:sf -MemberType NoteProperty -Name appRelativeServerCodeRootPath -Value "App_Code\sf-posh-extensions"

$Script:moduleUserDir = "$Global:HOME\documents\sf-posh"
if (-not (Test-Path $Script:moduleUserDir)) {
    New-Item -Path $Script:moduleUserDir -ItemType Directory
}

. "$PSScriptRoot\bootstrap\common.ps1"
. "$PSScriptRoot\bootstrap\init-config.ps1"
. "$PSScriptRoot\bootstrap\initialize-events.ps1"
. "$PSScriptRoot\bootstrap\init-psPrompt.ps1"
. "$PSScriptRoot\bootstrap\load-scripts.ps1"
. "$PSScriptRoot\bootstrap\run-upgrades.ps1"
