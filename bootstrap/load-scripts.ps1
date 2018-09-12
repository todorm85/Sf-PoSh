function Load-ScriptFiles ($path) {
    Get-ChildItem -Path $path -Filter '*.ps1' -Recurse | Where-Object { $_.BaseName -ne "init" }
}

function Load-InitScriptFiles ($path) {
    Get-ChildItem -Path $path -Filter '*.ps1' -Recurse | Where-Object { $_.BaseName -eq "init" }
}

# Do not dot source in function scope it won`t be loaded inside the module
Load-ScriptFiles "$PSScriptRoot\..\core" | ForEach-Object { . $_.FullName }
Load-InitScriptFiles "$PSScriptRoot\..\core" | ForEach-Object { . $_.FullName }