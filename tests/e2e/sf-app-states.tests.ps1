. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    
    Describe "States should" -Tags ("states") {
        It "save and then restore app_data folder and database" {
            set-testProject
            [SfProject]$project = proj-getCurrent
            $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
            [string]$stateName = generateRandomName
            $stateName = $stateName.Replace('-', '_')
            # $statePath = "$($Script:globalContext.webAppPath)/dev-tool/states/$stateName"

            $beforeSaveFilePath = "$configsPath\before_$stateName"
            New-Item $beforeSaveFilePath
            
            states-save -stateName $stateName
            
            # Test-Path "$statePath\$dbName.bak" | Should -BeTrue
            $afterSaveFilePath = "$configsPath\after_$stateName"
            New-Item $afterSaveFilePath
            Remove-Item -Path $beforeSaveFilePath
            $dbName = db-getNameFromDataConfig
            $dbName | Should -Not -BeNullOrEmpty
            
            $table = 'sf_xml_config_items'
            $columns = "path, dta, last_modified, id"
            $values = "'test', '<testConfigs/>', '$([System.DateTime]::Now.ToString())', '$([System.Guid]::NewGuid())'"
            sql-insert-items -dbName $dbName -tableName $table -columns $columns -values $values

            $select = 'dta'
            $where = "dta = '<testConfigs/>'"
            $config = sql-get-items -dbName $dbName -tableName $table -whereFilter $where -selectFilter $select
            $config | Should -Not -BeNullOrEmpty

            states-restore -stateName $stateName

            Test-Path $beforeSaveFilePath | Should -BeTrue
            Test-Path $afterSaveFilePath | Should -BeFalse
            $config = sql-get-items -dbName $dbName -selectFilter $select -whereFilter $where -tableName $table 
            $config | Should -BeNullOrEmpty
        }
    }
}
