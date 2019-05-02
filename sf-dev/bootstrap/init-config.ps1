$Script:moduleUserDir = "$Global:HOME\documents\sf-dev"
if (-not (Test-Path $Script:moduleUserDir)) {
    New-Item -Path $Script:moduleUserDir -ItemType Directory
}

$defaultConfigPath = "$PSScriptRoot\default_config.json"
$userConfigPath = "$Script:moduleUserDir\config.json"
$config = get-userConfig -defaultConfigPath $defaultConfigPath -userConfigPath $userConfigPath

# for backwards compatibility should be removed
$Script:dataPath = "$Script:moduleUserDir\db.xml"
$Script:idPrefix = $config.idPrefix
$Script:projectsDirectory = [System.Environment]::ExpandEnvironmentVariables($config.projectsDirectory)
$Script:browserPath = $config.browserPath
$Script:vsPath = $config.vsPath
$Script:msBuildPath = $config.msBuildPath
$Script:tfsServerName = $config.tfsServerName
$Script:defaultUser = $config.sitefinityUser
$Script:defaultPassword = $config.sitefinityPassword
$Script:sqlServerInstance = $config.sqlServerInstance
$Script:sqlUser = $config.sqlUser
$Script:sqlPass = $config.sqlPass
$Script:predefinedBranches = $config.predefinedBranches