# init config
$defaultConfig = ".\config.ps1"
$userConf = ".\config.user.ps1"

. $defaultConfig
if (Test-Path $userConf) {
    . $userConf
}