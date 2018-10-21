# init config
$defaultConfig = ".\config.ps1"
$userConf = ".\config.user.ps1"

. $defaultConfig
if (Test-Path $userConf) {
    . $userConf
}

if ($script:customConfigPath -and (Test-Path $script:customConfigPath)) {
    . $script:customConfigPath
}
