$Script:moduleUserDir = "$Global:HOME\documents\sf-dev"
if (-not (Test-Path $Script:moduleUserDir)) {
    New-Item -Path $Script:moduleUserDir -ItemType Directory
}

$defaultConfigPath = "$PSScriptRoot\default_config.json"
$Script:userConfigPath = "$Script:moduleUserDir\config.json"
$configFile = get-userConfig -defaultConfigPath $defaultConfigPath -userConfigPath $userConfigPath

$config = New-Object PSCustomObject -Property @{
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
    predefinedBuildPaths = $configFile.predefinedBuildPaths
}

Add-Member -InputObject $GLOBAL:Sf -MemberType NoteProperty -Name config -Value $config 