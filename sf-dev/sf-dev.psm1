$GLOBAL:sf = [PSCustomObject]@{}

$Script:moduleUserDir = "$Global:HOME\documents\sf-dev"
if (-not (Test-Path $Script:moduleUserDir)) {
    New-Item -Path $Script:moduleUserDir -ItemType Directory
}

. "${PSScriptRoot}/bootstrap/init-config.ps1"
. "${PSScriptRoot}/bootstrap/init-psPrompt.ps1"
. "${PSScriptRoot}/bootstrap/load-scripts.ps1"

Set-Alias -Name sf-project-create -Value sd-project-create -Scope global
Set-Alias -Name sf-project-remove -Value sd-project-remove -Scope global
Set-Alias -Name sf-project-rename -Value sd-project-rename -Scope global
Set-Alias -Name sf-project-select -Value sd-project-select -Scope global
Set-Alias -Name sf-project-showCurrent -Value sd-project-show -Scope global
Set-Alias -Name sf-project-showAll -Value sd-project-showAll -Scope global
Set-Alias -Name sf-project-clone -Value sd-project-clone -Scope global

Export-ModuleMember -Function * -Alias *
