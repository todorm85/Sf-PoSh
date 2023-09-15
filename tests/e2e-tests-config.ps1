. dev-config.ps1

$GLOBAL:sf.config.idPrefix = "sfe"
$GLOBAL:sf.config.projectsDirectory = "c:\dev-sitefinities\e2e-tests"
$GLOBAL:sf.Config.dataPath = "$($GLOBAL:sf.Config.projectsDirectory)\e2e-tests-db.xml"
$GLOBAL:sf.config.pathToNginxConfig = "C:\nginx-tests\conf\nginx.conf"
    
if (!(Test-Path $GLOBAL:sf.config.projectsDirectory)) {
    New-Item $GLOBAL:sf.config.projectsDirectory -ItemType Directory
}