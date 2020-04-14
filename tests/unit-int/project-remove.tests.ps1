. "${PSScriptRoot}\load.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    function _validate-projectInitialized {
        param(
            $dBname
        )
            
        (Get-Website | ? name -eq $p.websiteName) | Should -Not -BeNullOrEmpty
        (sql-get-dbs | ? name -eq $dbName) | Should -Not -BeNullOrEmpty
        (Test-Path $p.webAppPath) | Should -BeTrue
    }

    Describe "Project remove should" {
        . "$PSScriptRoot\test-project-init.ps1"
        [SfProject]$p = sf-project-getCurrent
        $dbName = sf-db-getNameFromDataConfig
        
        It "is correctly initialized" {
            _validate-projectInitialized $dbName
        }

        It "throw when no project selected" {
            sf-project-setCurrent $null
            { sf-project-remove } | Should -Throw -ExpectedMessage "No project selected!"
        }

        It "is correctly initialized after unsuccessful delete attempt" {
            _validate-projectInitialized $dbName
        }

        It "not throw when one is selected" {
            sf-project-setCurrent $p
            { sf-project-remove } | Should -Not -Throw
        }

        It "remove website" {
            (Get-Website | ? name -eq $p.websiteName) | Should -BeNullOrEmpty
        }
        It "remove db" {
            (sql-get-dbs | ? name -eq $p.id) | Should -BeNullOrEmpty
        }
        It "remove files" {
            (Test-Path $p.webAppPath) | Should -BeFalse
        }

        . "$PSScriptRoot\test-project-teardown.ps1"
    }
}