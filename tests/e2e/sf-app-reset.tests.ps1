. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    
    Describe "Resetting app should" -Tags ("reset") {
        [SfProject]$project = set-testProject

        $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
        Test-Path $configsPath | Should -Be $true
        $dbName = sf-app-db-getName
        $dbName | Should -Not -BeNullOrEmpty
        $GLOBAL:Sf.sql.GetDbs() | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 1

        sf-app-reset

        It "remove app data and database" {            
            $GLOBAL:Sf.sql.GetDbs() | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 0
            Test-Path $configsPath | Should -Be $false            
        }

        It "start successfully after reset" {
            sf-app-reset -start
            Test-Path $configsPath | Should -Be $true
            $dbName = _sf-app-db-getName  $project.webAppPath
            $GLOBAL:Sf.sql.GetDbs() | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 1
        }
    }
}
