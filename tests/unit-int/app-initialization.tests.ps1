. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {
    Describe "Reinitializing should" {
        InTestProjectScope {
            [SfProject]$project = sf-project-get
    
            $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
            Test-Path $configsPath | Should -Be $true
            $dbName = sf-db-getNameFromDataConfig
            $dbName | Should -Not -BeNullOrEmpty
            sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 1
    
            It "throw when initialize without uninitialize first" {
                { sf-app-initialize } | Should -Throw -ExpectedMessage "Already initialized. Uninitialize first."
            }

            It "remove app data and database when uninitialize" {
                sf-app-uninitialize
                sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 0
                Test-Path $configsPath | Should -Be $false
            }
    
            It "create startup config successfully when reinitialize" {
                Mock sf-app-ensureRunning { }
                sf-app-reinitialize
                Test-Path "$configsPath\StartupConfig.config" | Should -Be $true
            }

            It "use the project id for the database and remove the old database when it had different name than the id" {
                sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 0
                Get-Content "$configsPath\StartupConfig.config" -Raw | Should -BeLike "*$($project.id)*"
            }

        }
    }
}