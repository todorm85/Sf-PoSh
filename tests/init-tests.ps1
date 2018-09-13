. "${PSScriptRoot}\utils.ps1"

$Script:dataPath = "${PSScriptRoot}\test-db.xml"
$Script:projectsDirectory = "e:\sitefinities\tests"
$Script:baseTestId = 'sf_test_'

if (-not (Test-Path $Script:projectsDirectory)) {
    New-Item $Script:projectsDirectory -ItemType Directory
}
        
Mock _generateId {
    $i = 0;
    while ($true) {
        $name = "${baseTestId}${i}"
        $isDuplicate = (_get-isIdDuplicate $name)
        if (-not $isDuplicate) {
            break;
        }
                
        $i++
    }
            
    return $name
}

. "${PSScriptRoot}\..\module\bootstrap\load-scripts.ps1"
