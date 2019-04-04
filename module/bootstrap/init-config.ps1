function init-userConfig {
    param (
        [string]$defaultConfigPath,
        [string]$userConfigPath
    )
    
    $defaultConfig = Get-Content $defaultConfigPath | ConvertFrom-Json
    if (!(Test-Path $userConfigPath)) {
        $defaultConfig | ConvertTo-Json | Out-File $userConfigPath
    }
    else {
        $userConfig = Get-Content $userConfigPath | ConvertFrom-Json
        # create new properties from default
        $defaultConfig.PSObject.Properties | ForEach-Object {
            if (!$userConfig.PSObject.Properties.Match($_.Name).length) {
                $userConfig | Add-Member -Type NoteProperty -Name $_.Name -Value $_.Value
            }
        }
        # remove unused properties from user
        $userConfig.PSObject.Properties | ForEach-Object {
            if (!$defaultConfig.PSObject.Properties.Match($_.Name).length) {
                $userConfig.PSObject.Properties.Remove($_.Name)
            }
        }
    
        $userConfig | ConvertTo-Json | Out-File $userConfigPath
    }

    $Global:config = $userConfig
}

$Global:moduleUserDir = "$Global:HOME\documents\sf-dev"
if (-not (Test-Path $Global:moduleUserDir)) {
    New-Item -Path $Global:moduleUserDir -ItemType Directory
}

$Global:dataPath = "$Global:moduleUserDir\db.xml"

$defaultConfigPath = "$PSScriptRoot\default_config.json"
$userConfigPath = "$Global:moduleUserDir\config.json"
init-userConfig -defaultConfigPath $defaultConfigPath -userConfigPath $userConfigPath

# for backwards compatibility should be removed
$config = $Global:config
$Global:idPrefix = $config.idPrefix
$Global:projectsDirectory = [System.Environment]::ExpandEnvironmentVariables($config.projectsDirectory)
$Global:browserPath = $config.browserPath
$Global:vsPath = $config.vsPath
$Global:tfPath = $config.tfPath
$Global:msBuildPath = $config.msBuildPath
$Global:tfsServerName = $config.tfsServerName
$Global:defaultUser = $config.sitefinityUser
$Global:defaultPassword = $config.sitefinityPassword
$Global:sqlServerInstance = $config.sqlServerInstance
$Global:sqlUser = $config.sqlUser
$Global:sqlPass = $config.sqlPass
$Global:predefinedBranches = $config.predefinedBranches