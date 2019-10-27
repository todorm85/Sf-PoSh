$Script:moduleUserDir = "$Global:HOME\documents\sf-dev"
if (-not (Test-Path $Script:moduleUserDir)) {
    New-Item -Path $Script:moduleUserDir -ItemType Directory
}

$Script:externalToolsPath = "$script:moduleUserDir\external-tools"
if (!(Test-Path $Script:externalToolsPath)) {
    New-Item -Path $Script:externalToolsPath -ItemType Directory
}

$Script:userConfigPath = "$Script:moduleUserDir\config.json"

. "${PSScriptRoot}/config/init-config.ps1"
. "${PSScriptRoot}/init-psPrompt.ps1"
. "${PSScriptRoot}/load-scripts.ps1"
