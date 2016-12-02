if (-not $sfToolLoaded) {
    . "${PSScriptRoot}\..\sfTool.ps1"
}

. "${PSScriptRoot}\sfe-tests\sf-tests-runner.ps1"
. "${PSScriptRoot}\sfe-tests\sf-tests-comparer.ps1"
. "${PSScriptRoot}\sfe-tests\sf-tests-converter.ps1"
