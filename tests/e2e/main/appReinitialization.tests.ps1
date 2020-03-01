. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    
    Describe "Resetting app should" -Tags ("reset") {
        [SfProject]$project = set-testProject

        $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
        Test-Path $configsPath | Should -Be $true
        $dbName = sd-db-getNameFromDataConfig
        $dbName | Should -Not -BeNullOrEmpty
        sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 1

        sd-app-uninitialize

        It "remove app data and database" {            
            sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 0
            Test-Path $configsPath | Should -Be $false            
        }

        It "start successfully after reset" {
            sd-app-reinitializeAndStart
            Test-Path $configsPath | Should -Be $true
            $dbName = _db-getNameFromDataConfig  $project.webAppPath
            sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 1
        }
    }
}
