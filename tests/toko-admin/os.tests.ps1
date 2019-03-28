. "$PSScriptRoot\Infrastructure\load-module.ps1"

InModuleScope toko-admin {
    Describe "unlock-allFiles" {
        BeforeEach {
            $ids = New-Object System.Collections.ArrayList
            Mock Get-Process { $ids.Add($Id) > $null }
            # Mock Stop-Process { }
        }

        It "stop all processes that are locking files when one process" {
            Mock execute-native { 
                "Copyright (C) 1997-2017 Mark Russinovich"
                "Sysinternals - www.sysinternals.com"
                "`n"
                "explorer.exe       pid: 10760  type: File          10D4: E:\dev-sitefinities\sf_dev_2\SitefinityWebApp\App_Data\Sitefinity"

            } -ParameterFilter { $command -and $command.Contains("\handle.exe") }

            unlock-allFiles "c:\dummy"

            $ids | Should -Be 10760
        }

        It "stop all processes that are locking files when more than one processes" {
            Mock execute-native { 
                "Copyright (C) 1997-2017 Mark Russinovich"
                "Sysinternals - www.sysinternals.com"
                "`n"
                "explorer.exe       pid: 10760  type: File          10D4: E:\dev-sitefinities\sf_dev_2\SitefinityWebApp\App_Data\Sitefinity"
                "explorer.exe       pid: 11760  type: File          10D4: E:\dev-sitefinities\sf_dev_2\SitefinityWebApp\App_Data\Sitefinity"

            } -ParameterFilter { $command -and $command.Contains("\handle.exe") }

            unlock-allFiles "c:\dummy"

            $ids[0] | Should -Be 10760
            $ids[1] | Should -Be 11760
        }

        It "consider only unique process ids" {
            Mock execute-native { 
                "Copyright (C) 1997-2017 Mark Russinovich"
                "Sysinternals - www.sysinternals.com"
                "`n"
                "explorer.exe       pid: 10760  type: File          10D4: E:\dev-sitefinities\sf_dev_2\SitefinityWebApp\App_Data\Sitefinity"
                "explorer.exe       pid: 10763  type: File          10D4: E:\dev-sitefinities\sf_dev_2\SitefinityWebApp\App_Data\Sitefinity"
                "explorer.exe       pid: 10763  type: File          10D4: E:\dev-sitefinities\sf_dev_2\SitefinityWebApp\App_Data\Sitefinity"
                "explorer.exe       pid: 11760  type: File          10D4: E:\dev-sitefinities\sf_dev_2\SitefinityWebApp\App_Data\Sitefinity"

            } -ParameterFilter { $command -and $command.Contains("\handle.exe") }

            unlock-allFiles "c:\dummy"

            $ids[0] | Should -Be 10760
            $ids[1] | Should -Be 10763
            $ids[2] | Should -Be 11760
        }
        
        It "do nothing when no locking processes" {
            Mock execute-native { 
                "Copyright (C) 1997-2017 Mark Russinovich"
                "Sysinternals - www.sysinternals.com"
                "`n"
            } -ParameterFilter { $command -and $command.Contains("\handle.exe") }

            unlock-allFiles "c:\dummy"

            Assert-MockCalled Get-Process -Times 0 -Scope It
            $ids | Should -HaveCount 0
        }
    }
}