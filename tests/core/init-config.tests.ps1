. "${PSScriptRoot}\..\..\sf-dev\bootstrap\init-config.ps1"

Describe "init-config should" {

    $defaultConfigPath = "y:\default.json"
    $defaultConfig = [PSCustomObject]@{
        DefaultSetting = "DefaultSettingValue"
    }

    $userConfigPath = "y:\default.user.json"
    $userConfig = [PSCustomObject]@{
        DefaultSetting = "DefaultSettingValueModified"
    }

    $Global:result

    BeforeEach {

        Mock Get-Content {
            $defaultConfig | ConvertTo-Json        
        } -ParameterFilter { $Path -and $Path -eq $defaultConfigPath }

        Mock Get-Content {
            $userConfig | ConvertTo-Json        
        } -ParameterFilter { $Path -and $Path -eq $userConfigPath }

        Mock Out-File {
            $Global:result = $InputObject | ConvertFrom-Json
        }

    }

    It "create empty user config when none found" {
        Mock Test-Path {
            $false
        } -ParameterFilter { $Path -and $Path -eq $userConfigPath }

        init-userConfig -defaultConfigPath $defaultConfigPath -userConfigPath $userConfigPath
        $Global:result | Should -BeLike $defaultConfig
    }

    It "update existing user config when default one exists with new settings" {
        $defaultConfig = [PSCustomObject]@{
            DefaultSetting = "DefaultSettingValue"
            NewSetting = "NewSettingValue"
        }

        $userConfig = [PSCustomObject]@{
            DefaultSetting = "DefaultSettingValue"
        }

        Mock Test-Path {
            $true
        } -ParameterFilter { $Path -and $Path -eq $userConfigPath }

        init-userConfig -defaultConfigPath $defaultConfigPath -userConfigPath $userConfigPath
        $Global:result | Should -BeLike $defaultConfig
    }

    It "leave existing settings unchanged" {
        $defaultConfig = [PSCustomObject]@{
            DefaultSetting = "DefaultSettingValue"
            NewSetting = "NewSettingValue"
        }
        
        $userConfig = [PSCustomObject]@{
            DefaultSetting = "DefaultSettingValueModified"
        }

        Mock Test-Path {
            $true
        } -ParameterFilter { $Path -and $Path -eq $userConfigPath }

        init-userConfig -defaultConfigPath $defaultConfigPath -userConfigPath $userConfigPath
        $Global:result.DefaultSetting | Should -Be "DefaultSettingValueModified"
    }

    It "remove settings from user config that do not exist in default config" {
        $defaultConfig = [PSCustomObject]@{
            DefaultSetting = "DefaultSettingValue"
        }
        
        $userConfig = [PSCustomObject]@{
            DefaultSetting = "DefaultSettingValue"
            OldSetting = "OldSettingValue"
        }

        Mock Test-Path {
            $true
        } -ParameterFilter { $Path -and $Path -eq $userConfigPath }

        init-userConfig -defaultConfigPath $defaultConfigPath -userConfigPath $userConfigPath
        $Global:result | Should -BeLike $defaultConfig
    }
}
