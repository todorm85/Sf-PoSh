
function get-userConfig {
    param (
        [Parameter(Mandatory=$true)][string]$defaultConfigPath,
        [Parameter(Mandatory=$true)][string]$userConfigPath
    )
    
    if (!(Test-Path $defaultConfigPath)) {
        throw "Default config path not found."
    }

    $defaultConfig = Get-Content $defaultConfigPath | ConvertFrom-Json

    if (!(Test-Path $userConfigPath)) {
        $defaultConfig | ConvertTo-Json | Out-File $userConfigPath
        $userConfig = $defaultConfig
    }
    else {
        try {
            $userConfig = Get-Content $userConfigPath | ConvertFrom-Json
        }
        catch {
            throw "Corrupted user config at $userConfigPath. Probably not a json format? Inner exception: $_"
        }

        if (!$userConfig) {
            $userConfig = New-Object -TypeName psobject
        }

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

    return $userConfig
}
