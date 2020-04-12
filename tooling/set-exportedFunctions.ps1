Param([string]$path)

if (!$path) {
    $path = "$PSScriptRoot\..\sf-dev"
}

$scripts = Get-ChildItem $path -Directory -Exclude "bootstrap" | Get-ChildItem -Recurse | Where-Object { $_.Extension -eq '.ps1' -and $_.Name -notlike "*.init.ps1" -and $_.Name -notlike "*.tests.ps1"}

$modulesLines = $scripts | Get-Content
$functionsLines = $modulesLines | Where-Object { $_.contains("function") }

$functionNamePattern = "^\s*function\s+?(?<name>[\w-]+?)\s.*$"
$functions = $functionsLines | Where-Object { $_ -match $functionNamePattern } | ForEach-Object { $Matches["name"] } | Where-Object { !$_.StartsWith("_") }
$functionsEntry = ''
$functions | ForEach-Object { $functionsEntry += "'$_', "}
$functionsEntry = $functionsEntry.TrimEnd(@(',', ' '))

# update psd
$psdPath = "$PSScriptRoot\..\sf-dev\sf-dev.psd1";
$psdContent = ""
Get-Content -Path $psdPath | ForEach-Object {
    $newLine = $_
    $key = "    FunctionsToExport = ";
    if ($_.Contains($key)) {
        $newLine = "$key$functionsEntry"
    }

    $psdContent += "$newLine$([Environment]::NewLine)"
}

$psdContent | Out-File -FilePath $psdPath -Encoding utf8 -NoNewline