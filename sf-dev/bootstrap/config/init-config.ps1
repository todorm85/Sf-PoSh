$userConfigPath = "$Script:moduleUserDir\config.json"
. "$PSScriptRoot\get-userConfig.ps1"

$defaultConfigPath = "$PSScriptRoot\default_config.json"

$configFile = get-userConfig -defaultConfigPath $defaultConfigPath -userConfigPath $userConfigPath
Add-Member -InputObject $configFile -MemberType NoteProperty -Name dataPath -Value "$Script:moduleUserDir\db.xml"
$configFile.projectsDirectory = [System.Environment]::ExpandEnvironmentVariables($configFile.projectsDirectory)

Add-Member -InputObject $GLOBAL:Sf -MemberType NoteProperty -Name config -Value $configFile
