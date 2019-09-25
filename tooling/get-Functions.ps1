Param([string]$path)

if (!$path) {
    $path = "$PSScriptRoot\..\sf-dev\core"
}

$scripts = Get-ChildItem $path -Recurse | Where-Object { $_.Extension -eq '.ps1'}
# functions discovery
$modulesLines = $scripts | Get-Content
# $functionsLines = $modulesLines | Where-Object { $_.contains("function") }

$functionNamePattern = "(^.*?\s|^)(?<name>_.+?-.+?)(\s.*$|$)"
$modulesLines | Where-Object { $_ -match $functionNamePattern } | % { $Matches["name"] }

# $res = ''
# $filteredNames | % { $res = "$res, '$_'" }
# $res = $res.Remove(0,2)
# $res | Set-Clipboard