$GLOBAL:sf = [PSCustomObject]@{ }

$Script:moduleUserDir = "$Global:HOME\documents\sf-dev"
if (-not (Test-Path $Script:moduleUserDir)) {
    New-Item -Path $Script:moduleUserDir -ItemType Directory
}

. "${PSScriptRoot}/bootstrap/init-config.ps1"
if ($Global:OnAfterConfigInit) {
    $Global:OnAfterConfigInit | % { Invoke-Command -ScriptBlock $_ }
}

. "${PSScriptRoot}/bootstrap/init-psPrompt.ps1"
. "${PSScriptRoot}/bootstrap/load-scripts.ps1"


$scripts = @(
    # upgrade projects with not cached branch and site name when upgrading to 15.5.0
    { 
        param($oldVersion)
        if ((_isFirstVersionLower $oldVersion "15.5.0")) {
            sd-project-getAll | % { _proj-initialize $_; }
        }
    }
)
    
upgrade -upgradeScripts $scripts
    
Set-Alias -Name sf-new -Value sd-project-new -Scope global
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
Set-Alias -Name sf-openSolution -Value sd-sol-open -Scope global
Set-Alias -Name sf-setSiteDomain -Value sd-iisSite-changeDomain -Scope global

Export-ModuleMember -Function * -Alias *