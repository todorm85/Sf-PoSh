. "$PSScriptRoot\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    
    Describe "init-config should" {

        $mockDefaultConfigPath = "y:\default.json"
        $defaultConfig = [PSCustomObject]@{
            DefaultSetting = "DefaultSettingValue"
        }

        $userConfigPath = "y:\default.user.json"
        $userConfig = [PSCustomObject]@{
            DefaultSetting = "DefaultSettingValueModified"
        }

        $Script:result

        BeforeEach {

            Mock Test-Path {
                $true
            } -ParameterFilter { $Path -and $Path -eq $mockDefaultConfigPath }

            Mock Get-Content {
                $defaultConfig | ConvertTo-Json        
            } -ParameterFilter { $Path -and $Path -eq $mockDefaultConfigPath }

            Mock Get-Content {
                $userConfig | ConvertTo-Json        
            } -ParameterFilter { $Path -and $Path -eq $userConfigPath }

            Mock Test-Path {
                $true
            } -ParameterFilter { $Path -and $Path -eq $userConfigPath }

            Mock Out-File {
                $Script:result = $InputObject | ConvertFrom-Json
            }
        }

        It "create empty user config when none found" {
            Mock Test-Path {
                $false
            } -ParameterFilter { $Path -and $Path -eq $userConfigPath }

            get-userConfig -defaultConfigPath $mockDefaultConfigPath -userConfigPath $userConfigPath
            $Script:result | Should -BeLike $defaultConfig
        }

        It "create empty user config when empty file found" {
            Mock Get-Content {
                ""
            } -ParameterFilter { $Path -and $Path -eq $userConfigPath }

            get-userConfig -defaultConfigPath $mockDefaultConfigPath -userConfigPath $userConfigPath
            $Script:result | Should -BeLike $defaultConfig
        }

        It "throw when corrupted user config found" {
            Mock Get-Content {
                "\ffdsf'f;sdfll"
            } -ParameterFilter { $Path -and $Path -eq $userConfigPath }

            { get-userConfig -defaultConfigPath $mockDefaultConfigPath -userConfigPath $userConfigPath } | Should -Throw -ExpectedMessage 'Corrupted user config at'
        }

        It "update existing user config when default one exists with new settings" {
            $defaultConfig = [PSCustomObject]@{
                DefaultSetting = "DefaultSettingValue"
                NewSetting     = "NewSettingValue"
            }

            $userConfig = [PSCustomObject]@{
                DefaultSetting = "DefaultSettingValue"
            }

            Mock Test-Path {
                $true
            } -ParameterFilter { $Path -and $Path -eq $userConfigPath }

            get-userConfig -defaultConfigPath $mockDefaultConfigPath -userConfigPath $userConfigPath
            $Script:result | Should -BeLike $defaultConfig
        }

        It "leave existing settings unchanged" {
            $defaultConfig = [PSCustomObject]@{
                DefaultSetting = "DefaultSettingValue"
                NewSetting     = "NewSettingValue"
            }
        
            $userConfig = [PSCustomObject]@{
                DefaultSetting = "DefaultSettingValueModified"
            }

            Mock Test-Path {
                $true
            } -ParameterFilter { $Path -and $Path -eq $userConfigPath }

            get-userConfig -defaultConfigPath $mockDefaultConfigPath -userConfigPath $userConfigPath
            $Script:result.DefaultSetting | Should -Be "DefaultSettingValueModified"
        }

        It "remove settings from user config that do not exist in default config" {
            $defaultConfig = [PSCustomObject]@{
                DefaultSetting = "DefaultSettingValue"
            }
        
            $userConfig = [PSCustomObject]@{
                DefaultSetting = "DefaultSettingValue"
                OldSetting     = "OldSettingValue"
            }

            Mock Test-Path {
                $true
            } -ParameterFilter { $Path -and $Path -eq $userConfigPath }

            get-userConfig -defaultConfigPath $mockDefaultConfigPath -userConfigPath $userConfigPath
            $Script:result | Should -BeLike $defaultConfig
        }
    }
}