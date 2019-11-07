function Get-ScriptFiles {
    Get-ChildItem -Path "$PSScriptRoot\..\" -Directory -Exclude "bootstrap" | Get-ChildItem -Filter '*.ps1' -Recurse
}

Import-Module WebAdministration -Force

# Do not dot source in function scope it won`t be loaded inside the module
Get-ScriptFiles | Where-Object Name -Like "*.init.ps1" | ForEach-Object { . $_.FullName }
Get-ScriptFiles | Where-Object Name -NotLike "*.init.ps1" | ForEach-Object { . $_.FullName }
