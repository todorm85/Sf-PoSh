# init config
$Script:configPath = ".\config.ps1"
$defaultConfigPath = ".\config.default.ps1"
if (-not (Test-Path $configPath)) {
    Copy-Item $defaultConfigPath $configPath
}

. $Script:configPath