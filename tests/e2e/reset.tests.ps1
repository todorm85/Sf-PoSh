. "$PSScriptRoot\init.ps1"

. "$testUtilsDir\load-module.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    
    Describe "Resetting app should" -Tags ("reset") {
        [SfProject]$project = set-testProject

        $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
        Test-Path $configsPath | Should -Be $true
        $dbName = sf-get-appDbName
        $dbName | Should -Not -BeNullOrEmpty
        $sql.GetDbs() | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 1

        sf-reset-app

        It "remove app data and database" {            
            $sql.GetDbs() | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 0
            Test-Path $configsPath | Should -Be $false            
        }

        It "start successfully after reset" {
            $sf.webApp.ResetApp()
            Test-Path $configsPath | Should -Be $true
            $dbName = get-currentAppDbName            
            $sql.GetDbs() | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 1
        }
    }
}