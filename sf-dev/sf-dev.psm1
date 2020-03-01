$GLOBAL:sf = [PSCustomObject]@{}

$Script:moduleUserDir = "$Global:HOME\documents\sf-dev"
if (-not (Test-Path $Script:moduleUserDir)) {
    New-Item -Path $Script:moduleUserDir -ItemType Directory
}

. "${PSScriptRoot}/bootstrap/init-config.ps1"
. "${PSScriptRoot}/bootstrap/init-psPrompt.ps1"
. "${PSScriptRoot}/bootstrap/load-scripts.ps1"

Set-Alias -Name sf-create -Value sd-project-create -Scope global
Set-Alias -Name sf-remove -Value sd-project-remove -Scope global
Set-Alias -Name sf-rename -Value sd-project-rename -Scope global
Set-Alias -Name sf-select -Value sd-project-select -Scope global
Set-Alias -Name sf-show -Value sd-project-show -Scope global
Set-Alias -Name sf-clone -Value sd-project-clone -Scope global
Set-Alias -Name sf-reinitialize -Value sd-app-reinitializeAndStart -Scope global
Set-Alias -Name sf-restart -Value sd-iisAppPool-Reset -Scope global
Set-Alias -Name sf-precompiledTemplates-add -Value sd-appPrecompiledTemplates-add -Scope global
Set-Alias -Name sf-precompiledTemplates-remove -Value sd-appPrecompiledTemplates-remove -Scope global
Set-Alias -Name sf-rebuild -Value sd-sol-rebuild -Scope global
Set-Alias -Name sf-build -Value sd-sol-build -Scope global
Set-Alias -Name sf-getLatest -Value sd-sourceControl-getLatestChanges -Scope global
Set-Alias -Name sf-save -Value sd-appStates-save -Scope global
Set-Alias -Name sf-restore -Value sd-appStates-restore -Scope global
Set-Alias -Name sf-subApp-set -Value sd-iisSubApp-set -Scope global
Set-Alias -Name sf-subApp-remove -Value sd-iisSubApp-remove -Scope global
Set-Alias -Name sf-openInBrowser -Value sd-iisSite-browse -Scope global

Export-ModuleMember -Function * -Alias *
