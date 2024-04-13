$elapsedScripts = [System.Diagnostics.Stopwatch]::StartNew()
$definitions = Get-Content "$PSScriptRoot\types.txt" | Out-String
Add-Type -TypeDefinition $definitions
Get-Content "$PSScriptRoot\scriptPaths.txt" | ForEach-Object { . "$PSScriptRoot\..\$_" }

$elapsedScripts.Stop();
Write-Host "Scripts load time: $($elapsedScripts.Elapsed.TotalSeconds) second(s)"
