param([switch]$int, [switch]$e2e)

. constants.ps1
$sfPoshDevTestsPath = "$sfPoshDevPath\..\tests"

$oldWarn = $Global:WarningPreference
$oldInfo = $Global:InformationPreference

$Global:WarningPreference = "SilentlyContinue"
$Global:InformationPreference = "SilentlyContinue"
if ($int) {
    Invoke-Pester $sfPoshDevTestsPath\unit-int
}
    
if ($e2e) {
    Invoke-Pester $sfPoshDevTestsPath\e2e
}

$Global:WarningPreference = $oldWarn
$Global:InformationPreference = $oldInfo