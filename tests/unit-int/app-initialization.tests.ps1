. "${PSScriptRoot}\load.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"
    Describe "Reinitializing should" {
        . "$PSScriptRoot\test-project-init.ps1"
        [SfProject]$project = sd-project-getCurrent
    
        $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
        Test-Path $configsPath | Should -Be $true
        $dbName = sd-db-getNameFromDataConfig
        $dbName | Should -Not -BeNullOrEmpty
        sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 1
    
        It "remove app data and database when uninitialize" {
            sd-app-uninitialize
            sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 0
            Test-Path $configsPath | Should -Be $false
        }
    
        It "create startup config successfully when reinitialize" {
            Mock sd-app-waitForSitefinityToStart { }
            $mock = Mock sd-app-uninitialize { }
            sd-app-reinitializeAndStart
            Test-Path "$configsPath\StartupConfig.config" | Should -Be $true
            Assert-MockCalled sd-app-uninitialize
        }

        . "$PSScriptRoot\test-project-teardown.ps1"
    }
}