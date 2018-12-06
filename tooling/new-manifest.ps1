Param(
    $env
)

# module discovery
$rootModule = "sf-dev"
$scripts = Get-ChildItem "$PSScriptRoot\..\module\core" -Recurse | where { $_.Extension -eq '.ps1'}
# functions discovery
$modulesLines = $scripts | Get-Content
$functionsLines = $modulesLines | where { $_.contains("function") }

$functionNamePattern = "^\s*?function\s+?(?<name>(sf-).+?)\s+({|\().*$"
$filteredNames = $functionsLines | where { $_ -match $functionNamePattern } | % { $Matches["name"] }
$functionNames = New-Object System.Collections.ArrayList($null)
$functionNames.AddRange($filteredNames) > $null

if ($env -eq 'dev') {
    $functionNames = '*'
}

# generate manifest
New-ModuleManifest `
    -Path "$PSScriptRoot\..\module\sf-dev.psd1" `
    -RootModule $rootModule `
    -ModuleVersion '1.0' `
    -FunctionsToExport $functionNames `
    -CmdletsToExport '' `
    -VariablesToExport '' `
    -Author 'Todor Mitskovski' `
    -Description 'Sitefinity core dev automation tools' `
    -ScriptsToProcess 'bootstrap\load-nestedModules.ps1' `
    -PowerShellVersion '5.0' -ClrVersion '4.0';