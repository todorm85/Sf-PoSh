# module discovery
$rootModule = "sf-dev"
$scripts = Get-ChildItem "$PSScriptRoot/module" -Recurse | where { $_.Extension -eq '.ps1' -or $_.Extension -eq '.psm1'}
$nestedmodulesNames = $scripts | where { $_.BaseName -ne $rootModule -and $_.Extension -eq '.psm1'} | % { $_.BaseName }
$requiredModules = "Dev-Domains"
# functions discovery
$modulesLines = $scripts | Get-Content
$functionsLines = $modulesLines | where { $_.contains("function") }

$functionNamePattern = "^\s*?function\s+?(?<name>(sf-).+?)\s+({|\().*$"
$filteredNames = $functionsLines | where { $_ -match $functionNamePattern } | % { $Matches["name"] }
$functionNames = New-Object System.Collections.ArrayList($null)
$functionNames.AddRange($filteredNames) > $null
# $functionNames.Add("_get-selectedProject") > $null

# generate manifest
New-ModuleManifest `
    -Path "$PSScriptRoot/module/$rootModule.psd1" `
    -RootModule $rootModule `
    -ModuleVersion '1.0' `
    -NestedModules $nestedmodulesNames `
    -FunctionsToExport $functionNames `
    -CmdletsToExport '' `
    -VariablesToExport '' `
    -Author 'Todor Mitskovski' `
    -Description 'Sitefinity core dev automation tools' `
    -RequiredModules $requiredModules `
    -ModuleList
    -PowerShellVersion '5.0' -ClrVersion '4.0';


# type in ps console window to generate documentation form comments in functions
# Get-Command -Module SfTool | % { Get-Help $_ -full; Write-Host "`n----------------------------------------------------`n";} >> export.txt