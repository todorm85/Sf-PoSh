$definitions = Get-Content "$PSScriptRoot\types.txt" | Out-String
Add-Type -TypeDefinition $definitions
Get-Content "$PSScriptRoot\scriptPaths.txt" | ForEach-Object { . "$PSScriptRoot\..\$_" }
