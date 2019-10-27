. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    
    Describe "States should" -Tags ("states") {
        It "save and then restore app_data folder and database" {
            set-testProject
            [SfProject]$project = sf-proj-getCurrent
            $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
            [string]$stateName = generateRandomName
            $stateName = $stateName.Replace('-', '_')
            # $statePath = "$($Script:globalContext.webAppPath)/sf-dev-tool/states/$stateName"

            $beforeSaveFilePath = "$configsPath\before_$stateName"
            New-Item $beforeSaveFilePath
            
            sf-app-states-save -stateName $stateName
            
            # Test-Path "$statePath\$dbName.bak" | Should -BeTrue
            $afterSaveFilePath = "$configsPath\after_$stateName"
            New-Item $afterSaveFilePath
            Remove-Item -Path $beforeSaveFilePath
            $dbName = sf-app-db-getName
            $dbName | Should -Not -BeNullOrEmpty
            
            $table = 'sf_xml_config_items'
            $columns = "path, dta, last_modified, id"
            $values = "'test', '<testConfigs/>', '$([System.DateTime]::Now.ToString())', '$([System.Guid]::NewGuid())'"
            $GLOBAL:Sf.sql.InsertItems($dbName, $table, $columns, $values)

            $select = 'dta'
            $where = "dta = '<testConfigs/>'"
            $config = $GLOBAL:Sf.sql.GetItems($dbName, $table, $where, $select)
            $config | Should -Not -BeNullOrEmpty

            sf-app-states-restore -stateName $stateName

            Test-Path $beforeSaveFilePath | Should -BeTrue
            Test-Path $afterSaveFilePath | Should -BeFalse
            $config = $GLOBAL:Sf.sql.GetItems($dbName, $table, $where, $select)
            $config | Should -BeNullOrEmpty
        }
    }
}
