if (!$Global:SfEvents_OnAfterConfigInit) { $Global:SfEvents_OnAfterConfigInit = @() }
$Global:SfEvents_OnAfterConfigInit += {
    $GLOBAL:sf.config.projectsDirectory = "e:\sf-posh-int-tests"
    $path = "$($GLOBAL:sf.Config.projectsDirectory)\data-int-tests-db.xml"
    $GLOBAL:sf.Config.dataPath = $path
    if (Test-Path $path) {
        Remove-Item $path -Force
    }
    
    $GLOBAL:sf.Config.idPrefix = "sfi"
}

. "${PSScriptRoot}\..\utils\load-module.ps1"
