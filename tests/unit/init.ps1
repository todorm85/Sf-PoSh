$Script:dataPath = "$($Script:projectsDirectory)\data-tests-db.xml"
if (Test-Path $dataPath) {
    Remove-Item $dataPath -Force
}

. "${PSScriptRoot}\..\..\sf-dev\core\manager\manager.init.ps1"