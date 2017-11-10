$configPath = "${PSScriptRoot}\config.ps1"
$defaultConfigPath = "${PSScriptRoot}\config.default.ps1"
if (-not (Test-Path $configPath)) {
    Copy-Item $defaultConfigPath $configPath
}

. $configPath

. ${PSScriptRoot}\sf-load-scripts.ps1

# Startup logic
_sfData-init-data

Export-ModuleMember -Function * -Alias *