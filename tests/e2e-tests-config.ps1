. "$PSScriptRoot\common-config.ps1"

$GLOBAL:sf.config.idPrefix = "sfe"
$GLOBAL:sf.config.projectsDirectory = "e:\dev-sitefinities\e2e-tests"
$GLOBAL:sf.Config.dataPath = "$($GLOBAL:sf.Config.projectsDirectory)\e2e-tests-db.xml"
    
if (!(Test-Path $GLOBAL:sf.config.projectsDirectory)) {
    New-Item $GLOBAL:sf.config.projectsDirectory -ItemType Directory
}