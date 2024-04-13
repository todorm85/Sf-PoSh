param(
    [switch]$exportPrivate
)

. constants.ps1

# get functions from ps1 files
$functions = Get-ChildItem -Path "$PSScriptRoot\..\core" -File -Recurse | 
Where-Object { $_.Extension -eq '.ps1' -and $_.Name -notlike "*.init.ps1" } | 
Get-Content | Where-Object { $_.contains("function") } | 
Where-Object { $_ -match "^\s*function\s+?(?<name>[\w-]+?)\s.*$" } | 
ForEach-Object { $Matches["name"] } | Where-Object { $exportPrivate -or !$_.StartsWith("_") }
$functionsEntry = ''
$functions | ForEach-Object { $functionsEntry += "'$_', " }
$functionsEntry = $functionsEntry.TrimEnd(@(',', ' '))

# update psd
$psdPath = "$sfPoshDevPath\sf-posh.psd1";

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

function Get-CsharpClasses {
    Get-ChildItem -Path "$PSScriptRoot\..\core" -Filter '*.sfdev.cs' -Recurse
}

function Get-ScriptFiles {
    Get-ChildItem -Path "$PSScriptRoot\..\core" -Filter '*.ps1' -Recurse
}

# Do not dot source in function scope it won`t be loaded inside the module
# Type definitions must be added as a single bundle
$definitions = Get-CsharpClasses | % { Get-Content -Path $_.FullName -Raw } | Out-File "$PSScriptRoot\..\bootstrap\types.txt"
$devPath = (Get-Item $sfPoshDevPath).FullName
Get-ScriptFiles | Where-Object Name -Like "*.init.ps1" | ForEach-Object { $_.FullName.Replace($devPath, "") } | Out-File "$PSScriptRoot\..\bootstrap\scriptPaths.txt"
Get-ScriptFiles | Where-Object Name -NotLike "*.init.ps1" | ForEach-Object { $_.FullName.Replace($devPath, "") } | Out-File "$PSScriptRoot\..\bootstrap\scriptPaths.txt" -Append