. "$PSScriptRoot\init.ps1"

. "$testUtilsDir\load-module.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    
    Describe "States should" -Tags ("states") {
        It "save and then restore app_data folder and database" {
            set-testProject
            [SfProject]$project = proj-getCurrent
            $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
            [string]$stateName = generateRandomName
            $stateName = $stateName.Replace('-', '_')
            # $statePath = "$($Script:globalContext.webAppPath)/sf-dev-tool/states/$stateName"

            $beforeSaveFilePath = "$configsPath\before_$stateName"
            New-Item $beforeSaveFilePath
            
            app-states-save -stateName $stateName
            
            # Test-Path "$statePath\$dbName.bak" | Should -BeTrue
            $afterSaveFilePath = "$configsPath\after_$stateName"
            New-Item $afterSaveFilePath
            Remove-Item -Path $beforeSaveFilePath
            $dbName = app-db-getName
            $dbName | Should -Not -BeNullOrEmpty
            
            $table = 'sf_xml_config_items'
            $columns = "path, dta, last_modified, id"
            $values = "'test', '<testConfigs/>', '$([System.DateTime]::Now.ToString())', '$([System.Guid]::NewGuid())'"
            $tokoAdmin.sql.InsertItems($dbName, $table, $columns, $values)

            $select = 'dta'
            $where = "dta = '<testConfigs/>'"
            $config = $tokoAdmin.sql.GetItems($dbName, $table, $where, $select)
            $config | Should -Not -BeNullOrEmpty

            app-states-restore -stateName $stateName

            Test-Path $beforeSaveFilePath | Should -BeTrue
            Test-Path $afterSaveFilePath | Should -BeFalse
            $config = $tokoAdmin.sql.GetItems($dbName, $table, $where, $select)
            $config | Should -BeNullOrEmpty
        }
    }
}
