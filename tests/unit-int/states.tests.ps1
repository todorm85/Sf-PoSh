. "${PSScriptRoot}\load.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"
    Describe "States should" {
        . "$PSScriptRoot\test-project-init.ps1"

        It "save and then restore app_data folder and database" {
            [SfProject]$project = sd-project-getCurrent
            $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
            [string]$stateName = generateRandomName
            $stateName = $stateName.Replace('-', '_')
            # $statePath = "$($Script:globalContext.webAppPath)/dev-tool/states/$stateName"

            $beforeSaveFilePath = "$configsPath\before_$stateName"
            New-Item $beforeSaveFilePath

            $dbName = sd-db-getNameFromDataConfig
            $dbName | Should -Not -BeNullOrEmpty
            sql-createTable -dbName $dbName -tableName "tests"
            $table = 'tests'
            $columns = "test"
            $values = "'testVal1'"
            sql-insert-items -dbName $dbName -tableName $table -columns $columns -values $values

            sd-appStates-save -stateName $stateName

            # Test-Path "$statePath\$dbName.bak" | Should -BeTrue
            $afterSaveFilePath = "$configsPath\after_$stateName"
            New-Item $afterSaveFilePath
            Remove-Item -Path $beforeSaveFilePath
            
            $table = 'tests'
            $columns = "test"
            $values = "'testVal2'"
            sql-insert-items -dbName $dbName -tableName $table -columns $columns -values $values

            $select = 'test'
            $where = "test = 'testVal1'"
            $config = sql-get-items -dbName $dbName -tableName $table -whereFilter $where -selectFilter $select
            $config | Should -Not -BeNullOrEmpty

            $select = 'test'
            $where = "test = 'testVal2'"
            $config = sql-get-items -dbName $dbName -tableName $table -whereFilter $where -selectFilter $select
            $config | Should -Not -BeNullOrEmpty

            sd-appStates-restore -stateName $stateName

            $select = 'test'
            $where = "test = 'testVal1'"
            $config = sql-get-items -dbName $dbName -tableName $table -whereFilter $where -selectFilter $select
            $config | Should -Not -BeNullOrEmpty

            $select = 'test'
            $where = "test = 'testVal2'"
            $config = sql-get-items -dbName $dbName -tableName $table -whereFilter $where -selectFilter $select
            $config | Should -BeNullOrEmpty

            Test-Path $beforeSaveFilePath | Should -BeTrue
            Test-Path $afterSaveFilePath | Should -BeFalse
            $config = sql-get-items -dbName $dbName -selectFilter $select -whereFilter $where -tableName $table
            $config | Should -BeNullOrEmpty
        }

        . "$PSScriptRoot\test-project-teardown.ps1"
    }
}