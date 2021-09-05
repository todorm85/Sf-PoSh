. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {

    function _validate-projectInitialized {
        param(
            $dBname
        )
            
        (Get-Website | ? name -eq $p.websiteName) | Should -Not -BeNullOrEmpty
        (sql-get-dbs | ? name -eq $dbName) | Should -Not -BeNullOrEmpty
        (Test-Path $p.webAppPath) | Should -BeTrue
    }

    Describe "Project remove should" {
        InTestProjectScope {
        [SfProject]$p = sf-PSproject-get
        $dbName = sf-db-getNameFromDataConfig
        
        It "is correctly initialized" {
            _validate-projectInitialized $dbName
        }

        It "throw when no project selected" {
            sf-PSproject-setCurrent $null
            { sf-PSproject-remove } | Should -Throw -ExpectedMessage "No project selected"
        }

        It "is correctly initialized after unsuccessful delete attempt" {
            _validate-projectInitialized $dbName
        }

        It "not throw when one is selected" {
            sf-PSproject-setCurrent $p
            { sf-PSproject-remove } | Should -Not -Throw
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

        }
    }

    Describe "Project remove when no context passed and no project selected should" {
        InTestProjectScope {
        
        It "throw" {
            sf-PSproject-setCurrent $null
            { sf-PSproject-remove } | Should -Throw -ExpectedMessage "No project selected"
        }

        }
    }

    Describe "Project remove when no context passed and a project is selected should" {
        InTestProjectScope {
        It "remove the current selected" {
            sf-PSproject-remove
            { sf-PSproject-get } | Should -Throw -ExpectedMessage "No project selected!"
        }
        
        }
    }

    Describe "Project remove when context passed and same project is selected should" {
        InTestProjectScope {
        It "remove the current selected" {
            sf-PSproject-remove -project (sf-PSproject-get)
            { sf-PSproject-get } | Should -Throw -ExpectedMessage "No project selected!"
        }
        
        }
    }
    
    Describe "Project remove when context passed and another project is selected should" {
        InTestProjectScope {
        It "NOT remove the current selected" {
            $toDelete = sf-PSproject-get
            $another = [SfProject]::new()
            $another.id = "anotherId1"
            $path = "TestDrive:\project"
            New-Item $path -ItemType Directory
            $another.webAppPath = $path
            sf-PSproject-setCurrent $another
            sf-PSproject-remove -project $toDelete
            sf-PSproject-get | Should -Be $another
        }
        
        }
    }
}