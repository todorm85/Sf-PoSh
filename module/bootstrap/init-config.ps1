# init config
$defaultConfig = ".\config.ps1"
$userConf = "$home\documents\sf-dev\config.ps1"

. $defaultConfig
if (Test-Path $userConf) {
    . $userConf
}

if ($global:customConfigPath -and (Test-Path $global:customConfigPath)) {
    . $global:customConfigPath
}
