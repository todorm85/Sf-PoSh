Param([string]$path)

if (!$path) {
    $path = "$PSScriptRoot\..\"
}

$scripts = Get-ChildItem $path -Recurse | Where-Object { $_.Extension -eq '.ps1'}
$modulesLines = $scripts | Get-Content
$functionsLines = $modulesLines | Where-Object { $_.contains("function") }

$functionNamePattern = "^\s*function\s+?(?<name>([A-Za-z]+?_)+[A-Za-z]+?)\s.*$"
$functionsLines | Where-Object { $_ -match $functionNamePattern } | % { $Matches["name"] }

# $res = ''
# $filteredNames | % { $res = "$res, '$_'" }
# $res = $res.Remove(0,2)
# $res | Set-Clipboard
