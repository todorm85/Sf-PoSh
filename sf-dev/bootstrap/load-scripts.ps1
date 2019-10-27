function Load-ScriptFiles ($path) {
    Get-ChildItem -Path $path -Filter '*.ps1' -Recurse | Where-Object { -not $_.Name.EndsWith(".init.ps1") }
}

function Load-InitScriptFiles ($path) {
    Get-ChildItem -Path $path -Filter '*.ps1' -Recurse | Where-Object { $_.Name.EndsWith(".init.ps1") }
}

# Do not dot source in function scope it won`t be loaded inside the module
Load-InitScriptFiles "$PSScriptRoot\..\core" | ForEach-Object { . $_.FullName }
Load-InitScriptFiles "$PSScriptRoot\..\admin" | ForEach-Object { . $_.FullName }
Load-ScriptFiles "$PSScriptRoot\..\core" | ForEach-Object { . $_.FullName }
Load-ScriptFiles "$PSScriptRoot\..\admin" | ForEach-Object { . $_.FullName }
