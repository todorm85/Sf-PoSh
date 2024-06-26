. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {

    Describe "_db-getNameFromDataConfig" {
        $Script:xmlContent
        Mock _getDataConfig {
            $data = New-Object XML
            $data.LoadXml($Script:xmlContent)
            $data
        }

        it "should return correct dbname when many connection strings" {
            $Script:xmlContent = '<?xml version="1.0" encoding="utf-8"?>
            <dataConfig xmlns:config="urn:telerik:sitefinity:configuration" xmlns:type="urn:telerik:sitefinity:configuration:type" config:version="12.1.7100.0">
                <connectionStrings>
                    <add connectionString="data source=.;UID=sa;PWD=admin@2admin@2;initial catalog=sf_0" name="Sitefinity" />
                    <add connectionString="data source=.;UID=sa;PWD=admin@2admin@2;initial catalog=custom" name="Custom" />
                </connectionStrings>
            </dataConfig>'

            $result = _db-getNameFromDataConfig
            $result | Should -Be "sf_0"
        }

        it "should return correct dbname when one connection strings" {
            $Script:xmlContent = '<?xml version="1.0" encoding="utf-8"?>
            <dataConfig xmlns:config="urn:telerik:sitefinity:configuration" xmlns:type="urn:telerik:sitefinity:configuration:type" config:version="12.1.7100.0">
                <connectionStrings>
                    <add connectionString="data source=.;UID=sa;PWD=admin@2admin@2;initial catalog=sf_0" name="Sitefinity" />
                </connectionStrings>
            </dataConfig>'

            $result = _db-getNameFromDataConfig
            $result | Should -Be "sf_0"
        }

        it "should return null dbname when no connection strings" {
            $Script:xmlContent = '<?xml version="1.0" encoding="utf-8"?>
            <dataConfig xmlns:config="urn:telerik:sitefinity:configuration" xmlns:type="urn:telerik:sitefinity:configuration:type" config:version="12.1.7100.0">
                <connectionStrings>
                    <add connectionString="data source=.;UID=sa;PWD=admin@2admin@2;initial catalog=sf_0" name="custom" />
                </connectionStrings>
            </dataConfig>'

            $result = _db-getNameFromDataConfig
            $result | Should -BeNullOrEmpty
        }
    }
}
