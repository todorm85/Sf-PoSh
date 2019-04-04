Param(
    [Parameter(Mandatory=$true)]$version
    )

# module discovery
$filePath = "$PSScriptRoot\..\sf-dev\sf-dev.psd1"
$rootModule = ".\sf-dev.psm1"
$scripts = Get-ChildItem "$PSScriptRoot\..\sf-dev\core" -Recurse | Where-Object { $_.Extension -eq '.ps1'}
# functions discovery
$modulesLines = $scripts | Get-Content
$functionsLines = $modulesLines | Where-Object { $_.contains("function") }

$functionNamePattern = "^\s*?function\s+?(?<name>(sf-).+?)\s+({|\().*$"
$filteredNames = $functionsLines | Where-Object { $_ -match $functionNamePattern } | % { $Matches["name"] }
$functionNames = New-Object System.Collections.ArrayList($null)
$functionNames.AddRange($filteredNames) > $null

function create-module {
    # generate manifest
    New-ModuleManifest `
        -Path $filePath `
        -RootModule $rootModule `
        -ModuleVersion $version `
        -FunctionsToExport $functionNames `
        -CmdletsToExport '' `
        -VariablesToExport '' `
        -Author 'Todor Mitskovski' `
        -CompanyName ' ' `
        -Description 'Sitefinity core dev automation tools' `
        -ScriptsToProcess 'bootstrap\load-nestedModules.ps1' `
        -Guid "570fb657-4d88-4883-8b39-2dae4db1280c" `
        -PowerShellVersion '5.1' -ClrVersion '4.0';
}

#generate production
create-module

#generate development
$filePath = "$PSScriptRoot\..\sf-dev\sf-dev.dev.psd1"
$functionNames = '*'
create-module
