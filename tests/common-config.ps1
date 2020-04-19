$GLOBAL:sf.Config.projectsDirectory = "e:\dev-sitefinities"
$GLOBAL:sf.Config.dataPath = "$($GLOBAL:sf.Config.projectsDirectory)\dev-db.xml"
$GLOBAL:sf.config.idPrefix = "sfd"
$GLOBAL:sf.config.pathToNginxConfig = "C:\nginx-dev\conf\nginx.conf"

if (!(Test-Path $GLOBAL:sf.Config.projectsDirectory)) { 
    New-Item $GLOBAL:sf.Config.projectsDirectory -ItemType Directory 
}