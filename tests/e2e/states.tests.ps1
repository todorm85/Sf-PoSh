. "$PSScriptRoot\init.ps1"

. "$testUtilsDir\load-module.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    
    Describe "States should" -Tags ("states") {
        It "save and then restore app_data folder and database" {
            set-testProject
            [SfProject]$project = sf-get-currentProject
            $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
            [string]$stateName = generateRandomName
            $stateName = $stateName.Replace('-', '_')
            # $statePath = "$($Script:globalContext.webAppPath)/sf-dev-tool/states/$stateName"

            $beforeSaveFilePath = "$configsPath\before_$stateName"
            New-Item $beforeSaveFilePath
            
            $Global:sf.webApp.SaveDbAndConfigs($stateName)
            
            # Test-Path "$statePath\$dbName.bak" | Should -BeTrue
            $afterSaveFilePath = "$configsPath\after_$stateName"
            New-Item $afterSaveFilePath
            Remove-Item -Path $beforeSaveFilePath
            $dbName = sf-get-appDbName
            $dbName | Should -Not -BeNullOrEmpty
            [SqlClient]$sql = _get-sqlClient
            $table = 'sf_xml_config_items'
            $columns = "path, dta, last_modified, id"
            $values = "'test', '<testConfigs/>', '$([System.DateTime]::Now.ToString())', '$([System.Guid]::NewGuid())'"
            $sql.InsertItems($dbName, $table, $columns, $values)

            $select = 'dta'
            $where = "dta = '<testConfigs/>'"
            $config = $sql.GetItems($dbName, $table, $where, $select)
            $config | Should -Not -BeNullOrEmpty

            $Global:sf.webApp.RestoreDbAndConfigs($stateName)

            Test-Path $beforeSaveFilePath | Should -BeTrue
            Test-Path $afterSaveFilePath | Should -BeFalse
            $config = $sql.GetItems($dbName, $table, $where, $select)
            $config | Should -BeNullOrEmpty
        }
    }
}