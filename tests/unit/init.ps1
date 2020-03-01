$GLOBAL:sf.Config.dataPath = "$($GLOBAL:sf.Config.projectsDirectory)\data-tests-db.xml"
if (Test-Path $GLOBAL:sf.Config.dataPath) {
    Remove-Item $GLOBAL:sf.Config.dataPath -Force
}

_initManagerData
