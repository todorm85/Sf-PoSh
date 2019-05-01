$scripts = Get-ChildItem "$PSScriptRoot\..\sf-dev\core" -Recurse | Where-Object { $_.Extension -eq '.ps1'}
# functions discovery
$modulesLines = $scripts | Get-Content
$functionsLines = $modulesLines | Where-Object { $_.contains("function") }

$functionNamePattern = "^\s*?function\s+?(?<name>(sf-).+?)\s+({|\().*$"
$filteredNames = $functionsLines | Where-Object { $_ -match $functionNamePattern } | % { $Matches["name"] }
$functionNames = New-Object System.Collections.ArrayList($null)
$functionNames.AddRange($filteredNames) > $null

$functionNames