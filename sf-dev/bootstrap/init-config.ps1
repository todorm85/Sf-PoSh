$Script:moduleUserDir = "$Global:HOME\documents\sf-dev"
if (-not (Test-Path $Script:moduleUserDir)) {
    New-Item -Path $Script:moduleUserDir -ItemType Directory
}

$defaultConfigPath = "$PSScriptRoot\default_config.json"
$Script:userConfigPath = "$Script:moduleUserDir\config.json"
$configFile = get-userConfig -defaultConfigPath $defaultConfigPath -userConfigPath $userConfigPath

$Script:sfDevConfig = New-Object Config -Property @{
    dataPath           = "$Script:moduleUserDir\db.xml"
    idPrefix           = $configFile.idPrefix
    projectsDirectory  = [System.Environment]::ExpandEnvironmentVariables($configFile.projectsDirectory)
    browserPath        = $configFile.browserPath
    vsPath             = $configFile.vsPath
    msBuildPath        = $configFile.msBuildPath
    tfsServerName      = $configFile.tfsServerName
    defaultUser        = $configFile.sitefinityUser
    defaultPassword    = $configFile.sitefinityPassword
    sqlServerInstance  = $configFile.sqlServerInstance
    sqlUser            = $configFile.sqlUser
    sqlPass            = $configFile.sqlPass
    predefinedBranches = $configFile.predefinedBranches
}
    
# for backwards compatibility should be removed
$Script:dataPath = "$Script:moduleUserDir\db.xml"
$Script:idPrefix = $configFile.idPrefix
$Script:projectsDirectory = [System.Environment]::ExpandEnvironmentVariables($configFile.projectsDirectory)
$Script:browserPath = $configFile.browserPath
$Script:vsPath = $configFile.vsPath
$Script:msBuildPath = $configFile.msBuildPath
$Script:tfsServerName = $configFile.tfsServerName
$Script:defaultUser = $configFile.sitefinityUser
$Script:defaultPassword = $configFile.sitefinityPassword
$Script:sqlServerInstance = $configFile.sqlServerInstance
$Script:sqlUser = $configFile.sqlUser
$Script:sqlPass = $configFile.sqlPass
$Script:predefinedBranches = $configFile.predefinedBranches