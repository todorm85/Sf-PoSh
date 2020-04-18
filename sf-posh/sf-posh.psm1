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