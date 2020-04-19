. "$PSScriptRoot\common-config.ps1"

$GLOBAL:sf.Config.idPrefix = "sfi"
$GLOBAL:sf.config.projectsDirectory = "e:\dev-sitefinities\int-tests"
$GLOBAL:sf.Config.dataPath = "$($GLOBAL:sf.config.projectsDirectory)\int-tests-db.xml"

if (!(Test-Path $GLOBAL:sf.config.projectsDirectory)) {
    New-Item $GLOBAL:sf.config.projectsDirectory -ItemType Directory
}

if (Test-Path $GLOBAL:sf.Config.dataPath) {
    Remove-Item $GLOBAL:sf.Config.dataPath -Force
}