if (!$Global:OnAfterConfigInit) { $Global:OnAfterConfigInit = @() }
$Global:OnAfterConfigInit += {
    $path = "$($GLOBAL:sf.Config.projectsDirectory)\data-e2e-tests-db.xml"
    $GLOBAL:sf.Config.dataPath = $path
    $GLOBAL:sf.config.idPrefix = "sfe"
}

. "${PSScriptRoot}\..\utils\load-module.ps1"