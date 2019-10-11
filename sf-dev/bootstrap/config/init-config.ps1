$Script:moduleUserDir = "$Global:HOME\documents\sf-dev"
if (-not (Test-Path $Script:moduleUserDir)) {
    New-Item -Path $Script:moduleUserDir -ItemType Directory
}

$defaultConfigPath = "$PSScriptRoot\default_config.json"
$Script:userConfigPath = "$Script:moduleUserDir\config.json"

$configFile = get-userConfig -defaultConfigPath $defaultConfigPath -userConfigPath $userConfigPath
Add-Member -InputObject $configFile -MemberType NoteProperty -Name dataPath -Value "$Script:moduleUserDir\db.xml"
$configFile.projectsDirectory = [System.Environment]::ExpandEnvironmentVariables($configFile.projectsDirectory)

Add-Member -InputObject $GLOBAL:Sf -MemberType NoteProperty -Name config -Value $configFile
