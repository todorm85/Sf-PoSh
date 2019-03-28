# init config
$defaultConfigPath = "$PSScriptRoot\default_config.ps1"
$userConfigPath = "$global:moduleUserDir\config.ps1"

# validation
function validate-configState {
    param (
        $lastLoadedConfigPath
    )
    
    if (-not $global:projectsDirectory -or -not (Test-Path $global:projectsDirectory)) { 
        throw "Specify projects directory in $lastLoadedConfigPath" 
    }
    
    if (-not $global:sqlServerInstance) { 
        throw "Specify sql server instance path in $lastLoadedConfigPath" 
    }

    if (-not $global:browserPath -or -not (Test-Path $global:browserPath)) { 
        throw "Specify browser path in $lastLoadedConfigPath" 
    }

    if (-not $global:msBuildPath -or -not (Test-Path $global:msBuildPath)) { 
        throw "Specify msbuild path in $lastLoadedConfigPath" 
    }
    
    if (-not $global:dataPath) { 
        throw "Specify modue data path in $lastLoadedConfigPath" 
    }
    
    if (-not $global:defaultUser) { 
        throw "Specify default username in $lastLoadedConfigPath" 
    }

    if (-not $global:defaultPassword) { 
        throw "Specify default password in $lastLoadedConfigPath" 
    }
    
    if (-not $global:idPrefix) { 
        throw "Specify default id prefix in $lastLoadedConfigPath" 
    }
}

if (-not (Test-Path $userConfigPath)) {
    Copy-Item -Path $defaultConfigPath -Destination $userConfigPath
}

. $defaultConfigPath
. $userConfigPath

$lastLoadedConfigPath = $userConfigPath
if ($global:customConfigPath -and (Test-Path $global:customConfigPath)) {
    $lastLoadedConfigPath = $global:customConfigPath
    . $global:customConfigPath
}

validate-configState $lastLoadedConfigPath
