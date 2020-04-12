$GLOBAL:sf = [PSCustomObject]@{ }

$Script:moduleUserDir = "$Global:HOME\documents\sf-dev"
if (-not (Test-Path $Script:moduleUserDir)) {
    New-Item -Path $Script:moduleUserDir -ItemType Directory
}

. "${PSScriptRoot}/bootstrap/init-config.ps1"
if ($Global:SfEvents_OnAfterConfigInit) {
    $Global:SfEvents_OnAfterConfigInit | % { Invoke-Command -ScriptBlock $_ }
}

$Global:SfEvents_OnAfterProjectSelected = @()

. "${PSScriptRoot}/bootstrap/init-psPrompt.ps1"
. "${PSScriptRoot}/bootstrap/load-scripts.ps1"


$scripts = @(
    # upgrade projects with not cached branch and site name when upgrading to 15.5.0
    { 
        param($oldVersion)
        if ((_isFirstVersionLower $oldVersion "15.5.0")) {
            sf-project-getAll | % { _proj-initialize $_; }
        }
        if ((_isFirstVersionLower $oldVersion "15.5.1")) {
            sf-project-getAll | % { _proj-initialize $_; }
        }
        if ((_isFirstVersionLower $oldVersion "16.0.3")) {
            $data = New-Object XML
            $data.Load($GLOBAL:sf.Config.dataPath)
            $data.data.RemoveAttribute('version')
            $data.Save($GLOBAL:sf.Config.dataPath) > $null
        }
    }
)
    
_upgrade -upgradeScripts $scripts
$Global:InformationPreference = "Continue"
Export-ModuleMember -Function *