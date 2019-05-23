$Script:dataPath = "$($Script:projectsDirectory)\data-tests-db.xml"
if (Test-Path $Script:dataPath) {
    Remove-Item $Script:dataPath -Force
}

init-managerData