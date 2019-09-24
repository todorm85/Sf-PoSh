$GLOBAL:SfDevConfig.dataPath = "$($GLOBAL:SfDevConfig.projectsDirectory)\data-tests-db.xml"
if (Test-Path $GLOBAL:SfDevConfig.dataPath) {
    Remove-Item $GLOBAL:SfDevConfig.dataPath -Force
}

init-managerData