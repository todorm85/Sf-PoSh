$GLOBAL:Sf.Config.dataPath = "$($GLOBAL:Sf.Config.projectsDirectory)\data-tests-db.xml"
if (Test-Path $GLOBAL:Sf.Config.dataPath) {
    Remove-Item $GLOBAL:Sf.Config.dataPath -Force
}

InitManagerData