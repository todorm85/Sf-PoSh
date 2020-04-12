. "${PSScriptRoot}\load.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"
    Describe "Reinitializing should" {
        . "$PSScriptRoot\test-project-init.ps1"
        [SfProject]$project = sf-project-getCurrent
    
        $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
        Test-Path $configsPath | Should -Be $true
        $dbName = sf-db-getNameFromDataConfig
        $dbName | Should -Not -BeNullOrEmpty
        sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 1
    
        It "remove app data and database when uninitialize" {
            sf-app-uninitialize
            sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 0
            Test-Path $configsPath | Should -Be $false
        }
    
        It "create startup config successfully when reinitialize" {
            Mock sf-app-waitForSitefinityToStart { }
            $mock = Mock sf-app-uninitialize { }
            sf-app-reinitializeAndStart
            Test-Path "$configsPath\StartupConfig.config" | Should -Be $true
            Assert-MockCalled sf-app-uninitialize
        }

        . "$PSScriptRoot\test-project-teardown.ps1"
    }
}