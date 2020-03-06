. "$PSScriptRoot\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    Describe "unlock-allFiles" {
        BeforeEach {
            $ids = New-Object System.Collections.ArrayList
            Mock Get-Process { $ids.Add($Id) > $null }
            # Mock Stop-Process { }
            Mock Test-Path { $true } -ParameterFilter { $path -and $path.Contains("c:\dummy") }
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

    Describe "Hosts file operations" {
        $Script:hostsPath = "TestDrive:\hosts"
        New-Item -Path $Script:hostsPath -ItemType File

        It "adds entry with 127.0.0.1 address when it is not specified" {
            os-hosts-add -hostname "test.com"
            os-hosts-get | Should -Be "127.0.0.1 test.com"
        }

        It "removes an entry when it exists" {
            os-hosts-get | Should -Be "127.0.0.1 test.com"
            os-hosts-remove -hostname "test.com"
            os-hosts-get | Should -BeNullOrEmpty
        }

        It "does not duplicate entries" {
            os-hosts-add -hostname "test.com"
            os-hosts-add -hostname "test.com"
            os-hosts-get | Should -Be "127.0.0.1 test.com"
        }

        It "removes duplicate entries for given domain" {
            "127.0.0.1 test.com`n127.0.0.1 test.com" | Out-File $Script:hostsPath
            Get-Content -Path $Script:hostsPath | Should -HaveCount 2
            os-hosts-remove -hostname "test.com"
            Get-Content -Path $Script:hostsPath | Should -BeNullOrEmpty
        }

        It "adds entry with proper address when it is specified" {
            os-hosts-add -hostname "test.com" -address '192.168.1.1'
            os-hosts-get | Should -Be "192.168.1.1 test.com"
        }

        It "removes an entry with custom address when it exists" {
            os-hosts-get | Should -Be "192.168.1.1 test.com"
            os-hosts-remove -hostname "test.com"
            os-hosts-get | Should -BeNullOrEmpty
        }
    }

    Describe "_clean-emptyDirs" {
        function create-dirs {
            $Script:testPathRoot = "TestDrive:\root"
            New-Item -Path $Script:testPathRoot -ItemType Directory
            New-Item -Path "$Script:testPathRoot\child_1" -ItemType Directory
            New-Item -Path "$Script:testPathRoot\child_1\child_1_1" -ItemType Directory
            New-Item -Path "$Script:testPathRoot\child_2" -ItemType Directory
            New-Item -Path "$Script:testPathRoot\child_2\child_2_1" -ItemType Directory
            New-Item -Path "$Script:testPathRoot\child_2\child_2_1\child_3_1" -ItemType Directory
            New-Item -Path "$Script:testPathRoot\child_3" -ItemType Directory
            New-Item -Path "$Script:testPathRoot\child_3\f1.txt" -ItemType File
            New-Item -Path "$Script:testPathRoot\child_3\child_3_1" -ItemType File
            New-Item -Path "$Script:testPathRoot\child_4" -ItemType Directory
        }

        It "deletes all empty directories" {
            create-dirs
            _clean-emptyDirs -path $Script:testPathRoot
            $dirs = @(Get-ChildItem -Path $Script:testPathRoot)
            $dirs | Should -HaveCount 1
            $dirs[0].BaseName | Should -Be "child_3"
            Test-Path -Path "$Script:testPathRoot\child_3\f1.txt" | Should -BeTrue
        }
    }
}