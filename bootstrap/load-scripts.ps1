function Get-ScriptFiles ($path) {
    Get-ChildItem -Path $path -Filter '*.ps1' -Recurse
}

Get-ScriptFiles "$PSScriptRoot\..\infrastructure" | ForEach-Object { . $_.FullName }
Get-ScriptFiles "$PSScriptRoot\..\manager" | ForEach-Object { . $_.FullName }
Get-ScriptFiles "$PSScriptRoot\..\core" | ForEach-Object { . $_.FullName }