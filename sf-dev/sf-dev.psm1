$GLOBAL:sf = [PSCustomObject]@{ }

$Script:moduleUserDir = "$Global:HOME\documents\sf-dev"
if (-not (Test-Path $Script:moduleUserDir)) {
    New-Item -Path $Script:moduleUserDir -ItemType Directory
}

. "${PSScriptRoot}/bootstrap/init-config.ps1"
if ($Global:SfEvents_OnAfterConfigInit) {
    $Global:SfEvents_OnAfterConfigInit | % { Invoke-Command -ScriptBlock $_ }
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
        if ((_isFirstVersionLower $oldVersion "15.5.1")) {
            sd-project-getAll | % { _proj-initialize $_; }
        }
    }
)
    
upgrade -upgradeScripts $scripts

Export-ModuleMember -Function *