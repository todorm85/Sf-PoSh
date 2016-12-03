# to use in PS5 type "Install-Module ImportExcel" GitHub: dfinke/ImportExcel

. "${PSScriptRoot}\sfe-tests\sfTest-common.ps1"
. "${PSScriptRoot}\sfe-tests\sfTest-runner.ps1"
. "${PSScriptRoot}\sfe-tests\sfTest-comparer.ps1"
. "${PSScriptRoot}\sfe-tests\sfTest-converter.ps1"

Export-ModuleMember -Function '*'