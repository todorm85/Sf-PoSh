if (!$Global:OnAfterConfigInit) { $Global:OnAfterConfigInit = @() }
$Global:OnAfterConfigInit += {
    $path = "$($GLOBAL:sf.Config.projectsDirectory)\data-tests-db.xml"
    $GLOBAL:sf.Config.dataPath = $path
    if (Test-Path $path) {
        Remove-Item $path -Force
    }
    
    $GLOBAL:sf.Config.idPrefix = "sfi"
}

. "${PSScriptRoot}\..\utils\load-module.ps1"
