$Global:SfEvents_OnAfterConfigInit = {
    . "$PSScriptRoot\..\e2e-tests-config.ps1"
}

. "${PSScriptRoot}\..\utils\load-module.ps1"

$Global:testProjectDisplayName = 'created_from_TFS'
$Global:fromZipProjectName = 'created_from_zip'

InModuleScope sf-posh {
    Describe "Creating the project from branch should" {
        It "execute with correct initial state" {
            [SfProject[]]$projects = sf-project-get -all
            foreach ($proj in $projects) {
                sf-project-remove -project $proj -noPrompt
            }

            sf-project-new -displayName $Global:testProjectDisplayName -sourcePath 'https://prgs-sitefinity.visualstudio.com/Sitefinity/_git/sitefinity'

            $sitefinities = @(sf-project-get -all) | Where-Object { $_.displayName -eq $Global:testProjectDisplayName }
            $sitefinities | Should -HaveCount 1
            $Script:createdSf = [SfProject]$sitefinities[0]
            $Script:id = $createdSf.id
        }
        
        It "Set project data correctly" {
            $createdSf.branch | Should -Be ''
            $createdSf.solutionPath | Should -Be "$($GLOBAL:sf.Config.projectsDirectory)\${id}"
            $createdSf.webAppPath | Should -Be "$($GLOBAL:sf.Config.projectsDirectory)\${id}\SitefinityWebApp"
            $createdSf.websiteName | Should -Be $id
        }

        It "Create project artefacts correctly" {
            Test-Path "$($GLOBAL:sf.Config.projectsDirectory)\$id\$id.sln" | Should -Be $true
            Test-Path "$($GLOBAL:sf.Config.projectsDirectory)\$id\Telerik.Sitefinity.sln" | Should -Be $true
            Test-Path "IIS:\AppPools\${id}" | Should -Be $true
            Test-Path "IIS:\Sites\${id}" | Should -Be $true
            existsInHostsFile -searchParam $id | Should -Be $true
        }
    }

    Describe "Building should" {
        It "succeed after at least 3 retries" {
            sf-project-get -all | select -First 1 | sf-project-setCurrent
            sf-sol-build -retryCount 3
        }
    }

    Describe "Reinitializing should" -Tags ("reset") {
        It "has correct initial state" {
            sf-project-get -all | select -First 1 | sf-project-setCurrent
            [SfProject]$Script:project = sf-project-get
            sf-app-reinitialize
            $url = sf-iis-site-getUrl
            $result = _invokeNonTerminatingRequest $url
            $result | Should -Be 200

            $Script:configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
            Test-Path $configsPath | Should -Be $true
            $Script:dbName = sf-db-getNameFromDataConfig
            $dbName | Should -Not -BeNullOrEmpty
            sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 1
        }

        It "remove app data and database when uninitialize" {
            sf-app-uninitialize
            sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 0
            Test-Path $configsPath | Should -Be $false
        }

        It "start successfully after initialize" {
            sf-app-reinitialize
            Test-Path $configsPath | Should -Be $true
            $dbName = _db-getNameFromDataConfig $project.webAppPath
            $dbName | Should -Not -BeNullOrEmpty
            sql-get-dbs | Where-Object { $_.Name -eq $dbName } | Should -HaveCount 1
        }
    }

    Describe "States should" -Tags ("states") {        
        It "save and then restore app_data folder and database" {
            sf-project-get -all | select -First 1 | sf-project-setCurrent
            [SfProject]$project = sf-project-get
            $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
            [string]$stateName = generateRandomName
            $stateName = $stateName.Replace('-', '_')
            # $statePath = "$($Script:globalContext.webAppPath)/dev-tool/states/$stateName"

            $beforeSaveFilePath = "$configsPath\before_$stateName"
            New-Item $beforeSaveFilePath

            sf-states-save -stateName $stateName

            # Test-Path "$statePath\$dbName.bak" | Should -BeTrue
            $afterSaveFilePath = "$configsPath\after_$stateName"
            New-Item $afterSaveFilePath
            Remove-Item -Path $beforeSaveFilePath
            $dbName = sf-db-getNameFromDataConfig
            $dbName | Should -Not -BeNullOrEmpty

            $table = 'sf_xml_config_items'
            $columns = "path, dta, last_modified, id"
            $values = "'test', '<testConfigs/>', '$([System.DateTime]::Now.ToString())', '$([System.Guid]::NewGuid())'"
            sql-insert-items -dbName $dbName -tableName $table -columns $columns -values $values

            $select = 'dta'
            $where = "dta = '<testConfigs/>'"
            $config = sql-get-items -dbName $dbName -tableName $table -whereFilter $where -selectFilter $select
            $config | Should -Not -BeNullOrEmpty

            sf-states-restore -stateName $stateName

            Test-Path $beforeSaveFilePath | Should -BeTrue
            Test-Path $afterSaveFilePath | Should -BeFalse
            $config = sql-get-items -dbName $dbName -selectFilter $select -whereFilter $where -tableName $table
            $config | Should -BeNullOrEmpty
        }
    }

    Describe "Cloning project should" -Tags ("clone") {
        It "has correct initial state" {
            sf-project-get -all | select -First 1 | sf-project-setCurrent

            $sourceProj = sf-project-get

            $sourceName = $sourceProj.displayName
            $Script:cloneTestName = "$sourceName-clone" # TODO: stop using hardcoded convention here

            sf-project-get -all | Where-Object displayName -eq $cloneTestName | ForEach-Object {
                sf-project-remove -project $_ -noPrompt
            }

            sql-get-dbs | Where-Object { $_.name -eq $sourceProj.id } | Should -HaveCount 1

            # edit a file in source project and mark as changed in TFS
            $webConfigPath = "$($sourceProj.webAppPath)\web.config"
            [xml]$xmlData = Get-Content $webConfigPath
            [System.Xml.XmlElement]$appSettings = $xmlData.configuration.appSettings
            $newElement = $xmlData.CreateElement("add")
            $testKeyName = generateRandomName
            $newElement.SetAttribute("key", $testKeyName)
            $newElement.SetAttribute("value", "testing")
            $appSettings.AppendChild($newElement) > $null
            $xmlData.Save($webConfigPath) > $null
        }

        It "not throw" {
            sf-project-clone
            [SfProject]$Script:project = sf-project-get
            $Script:cloneTestId = $project.id
        }

        It "set project displayName" {
            $project.displayName | Should -Be $cloneTestName
        }

        It "set project branch" {
            $project.branch | Should -Be ''
        }

        It "set project solution path" {
            $project.solutionPath.ToLower().Contains($GLOBAL:sf.Config.projectsDirectory.ToLower()) | Should -Be $true
        }

        It "set project site" {
            $project.websiteName | Should -Be $cloneTestId
        }

        It "create project solution directory" {
            Test-Path $project.solutionPath | Should -Be $true
        }

        It "create a hosts file entry" {
            existsInHostsFile -searchParam $project.id | Should -Be $true
        }

        It "create a user friendly solution name" {
            Test-Path "$($project.solutionPath)\$($project.id).sln" | Should -Be $true
        }

        It "copy the original solution file" {
            Test-Path "$($project.solutionPath)\Telerik.Sitefinity.sln" | Should -Be $true
        }

        It "create website pool" {
            Test-Path "IIS:\AppPools\${cloneTestId}" | Should -Be $true
        }

        It "create website" {
            Test-Path "IIS:\Sites\${cloneTestId}" | Should -Be $true
        }

        It "create a copy of db" {
            sql-get-dbs | Where-Object { $_.name -eq $cloneTestId } | Should -HaveCount 1
        }

        sf-project-get -all | Where-Object displayName -eq $cloneTestName | ForEach-Object {
            sf-project-remove -project $_ -noPrompt
        }
    }

    Describe "Remove should" -Tags ("delete") {
        It "has correct initial state" {
            sf-project-get -all | select -First 1 | sf-project-setCurrent
            [SfProject]$Script:proj = sf-project-get
            $Script:testId = $proj.id

            $sitefinities = @(sf-project-get -all) | Where-Object { $_.id -eq $testId }
            $sitefinities | Should -HaveCount 1
            Test-Path "$($GLOBAL:sf.Config.projectsDirectory)\${testId}" | Should -Be $true
            Test-Path "IIS:\AppPools\${testId}" | Should -Be $true
            Test-Path "IIS:\Sites\${testId}" | Should -Be $true
            sql-get-dbs | Where-Object { $_.Name.Contains($testId) } | Should -HaveCount 1
            existsInHostsFile -searchParam $proj.id | Should -Be $true
        }
        
        It "not throw" {
            sf-project-remove -noPrompt
        }

        It "remove project from sf-posh" {
            $sitefinities = @(sf-project-get -all) | Where-Object { $_.id -eq $testId }
            $sitefinities | Should -HaveCount 0
        }

        It "delete the directory" {
            Test-Path "$($GLOBAL:sf.Config.projectsDirectory)\${testId}" | Should -Be $false
        }

        It "delete app pool" {
            Test-Path "IIS:\AppPools\${testId}" | Should -Be $false
        }

        It "delete website" {
            Test-Path "IIS:\Sites\${testId}" | Should -Be $false
        }

        It "delete DB" {
            sql-get-dbs | Where-Object { $_.Name.Contains($testId) } | Should -HaveCount 0
        }

        It "Remove entry from hosts file" {
            existsInHostsFile -searchParam $proj.id | Should -Be $false
        }
    }
}