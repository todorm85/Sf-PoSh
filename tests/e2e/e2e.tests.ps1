if (!$Global:OnAfterConfigInit) { $Global:OnAfterConfigInit = @() }
$Global:OnAfterConfigInit += {
    $path = "$($GLOBAL:sf.Config.projectsDirectory)\data-e2e-tests-db.xml"
    $GLOBAL:sf.Config.dataPath = $path
    $GLOBAL:sf.config.idPrefix = "sfe"
}

. "${PSScriptRoot}\..\utils\load-module.ps1"

$Global:testProjectDisplayName = 'created_from_TFS'
$Global:fromZipProjectName = 'created_from_zip'

InModuleScope sf-dev {
    . "${PSScriptRoot}\..\utils\test-util.ps1"

    Describe "Creating the project from branch should" {
        [SfProject[]]$projects = sd-project-getAll
        foreach ($proj in $projects) {
            sd-project-remove -context $proj
        }

        sd-project-new -displayName $Global:testProjectDisplayName -sourcePath '$/CMS/Sitefinity 4.0/Code Base'

        $sitefinities = @(sd-project-getAll) | Where-Object { $_.displayName -eq $Global:testProjectDisplayName }
        $sitefinities | Should -HaveCount 1
        $createdSf = [SfProject]$sitefinities[0]
        $id = $createdSf.id

        It "Set project data correctly" {
            $createdSf.branch | Should -Be '$/CMS/Sitefinity 4.0/Code Base'
            $createdSf.solutionPath | Should -Be "$($GLOBAL:sf.Config.projectsDirectory)\${id}"
            $createdSf.webAppPath | Should -Be "$($GLOBAL:sf.Config.projectsDirectory)\${id}\SitefinityWebApp"
            $createdSf.websiteName | Should -Be $id
        }

        It "Create project artefacts correctly" {
            Test-Path "$($GLOBAL:sf.Config.projectsDirectory)\$id\$($createdSf.displayName)($id).sln" | Should -Be $true
            Test-Path "$($GLOBAL:sf.Config.projectsDirectory)\$id\Telerik.Sitefinity.sln" | Should -Be $true
            Test-Path "IIS:\AppPools\${id}" | Should -Be $true
            Test-Path "IIS:\Sites\${id}" | Should -Be $true
            existsInHostsFile -searchParam $Global:testProjectDisplayName | Should -Be $true
        }
    }

    Describe "Building should" {
        sd-project-getAll | select -First 1 | sd-project-setCurrent
        It "succeed after at least 3 retries" {
            sd-sol-build -retryCount 3
        }
    }

    Describe "Reinitializing should" -Tags ("reset") {
        sd-project-getAll | select -First 1 | sd-project-setCurrent
        [SfProject]$project = sd-project-getCurrent
        sd-app-reinitializeAndStart
        $url = sd-iisSite-getUrl
        $result = _invokeNonTerminatingRequest $url
        $result | Should -Be 200

        $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
        Test-Path $configsPath | Should -Be $true
        $dbName = sd-db-getNameFromDataConfig
        $dbName | Should -Not -BeNullOrEmpty
        sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 1

        It "remove app data and database when uninitialize" {
            sd-app-uninitialize
            sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 0
            Test-Path $configsPath | Should -Be $false
        }

        It "start successfully after initialize" {
            sd-app-reinitializeAndStart
            Test-Path $configsPath | Should -Be $true
            $dbName = _db-getNameFromDataConfig  $project.webAppPath
            sql-get-dbs | Where-Object { $_.Name.Contains($dbName) } | Should -HaveCount 1
        }
    }

    Describe "States should" -Tags ("states") {
        sd-project-getAll | select -First 1 | sd-project-setCurrent

        It "save and then restore app_data folder and database" {
            [SfProject]$project = sd-project-getCurrent
            $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
            [string]$stateName = generateRandomName
            $stateName = $stateName.Replace('-', '_')
            # $statePath = "$($Script:globalContext.webAppPath)/dev-tool/states/$stateName"

            $beforeSaveFilePath = "$configsPath\before_$stateName"
            New-Item $beforeSaveFilePath

            sd-appStates-save -stateName $stateName

            # Test-Path "$statePath\$dbName.bak" | Should -BeTrue
            $afterSaveFilePath = "$configsPath\after_$stateName"
            New-Item $afterSaveFilePath
            Remove-Item -Path $beforeSaveFilePath
            $dbName = sd-db-getNameFromDataConfig
            $dbName | Should -Not -BeNullOrEmpty

            $table = 'sf_xml_config_items'
            $columns = "path, dta, last_modified, id"
            $values = "'test', '<testConfigs/>', '$([System.DateTime]::Now.ToString())', '$([System.Guid]::NewGuid())'"
            sql-insert-items -dbName $dbName -tableName $table -columns $columns -values $values

            $select = 'dta'
            $where = "dta = '<testConfigs/>'"
            $config = sql-get-items -dbName $dbName -tableName $table -whereFilter $where -selectFilter $select
            $config | Should -Not -BeNullOrEmpty

            sd-appStates-restore -stateName $stateName

            Test-Path $beforeSaveFilePath | Should -BeTrue
            Test-Path $afterSaveFilePath | Should -BeFalse
            $config = sql-get-items -dbName $dbName -selectFilter $select -whereFilter $where -tableName $table
            $config | Should -BeNullOrEmpty
        }
    }

    Describe "Cloning project should" {
        sd-project-getAll | select -First 1 | sd-project-setCurrent

        $sourceProj = sd-project-getCurrent

        $sourceName = $sourceProj.displayName
        $cloneTestName = "$sourceName-clone" # TODO: stop using hardcoded convention here

        sd-project-getAll | Where-Object displayName -eq $cloneTestName | ForEach-Object {
            sd-project-remove -context $_
        }

        sql-get-dbs | Where-Object { $_.name -eq $sourceProj.id } | Should -HaveCount 1

        # edit a file in source project and mark as changed in TFS
        $webConfigPath = "$($sourceProj.webAppPath)\web.config"
        tfs-checkout-file $webConfigPath > $null
        [xml]$xmlData = Get-Content $webConfigPath
        [System.Xml.XmlElement]$appSettings = $xmlData.configuration.appSettings
        $newElement = $xmlData.CreateElement("add")
        $testKeyName = generateRandomName
        $newElement.SetAttribute("key", $testKeyName)
        $newElement.SetAttribute("value", "testing")
        $appSettings.AppendChild($newElement)
        $xmlData.Save($webConfigPath) > $null

        sd-project-clone

        [SfProject]$project = sd-project-getCurrent
        $cloneTestId = $project.id

        It "set project displayName" {
            $project.displayName | Should -Be $cloneTestName
        }

        It "set project branch" {
            $project.branch | Should -Be '$/CMS/Sitefinity 4.0/Code Base'
        }

        It "set project solution path" {
            $project.solutionPath.Contains($GLOBAL:sf.Config.projectsDirectory) | Should -Be $true
        }

        It "set project site" {
            $project.websiteName | Should -Be $cloneTestId
        }

        It "create project solution directory" {
            Test-Path $project.solutionPath | Should -Be $true
        }

        It "create a hosts file entry" {
            existsInHostsFile -searchParam $project.displayName | Should -Be $true
        }

        It "create a user friendly solution name" {
            Test-Path "$($project.solutionPath)\$($project.displayName)($($project.id)).sln" | Should -Be $true
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

        sd-project-getAll | Where-Object displayName -eq $cloneTestName | ForEach-Object {
            sd-project-remove -context $_
        }
    }

    Describe "Remove should" -Tags ("delete") {
        sd-project-getAll | select -First 1 | sd-project-setCurrent
        [SfProject]$proj = sd-project-getCurrent
        $testId = $proj.id

        $sitefinities = @(sd-project-getAll) | Where-Object { $_.id -eq $testId }
        $sitefinities | Should -HaveCount 1
        Test-Path "$($GLOBAL:sf.Config.projectsDirectory)\${testId}" | Should -Be $true
        Test-Path "IIS:\AppPools\${testId}" | Should -Be $true
        Test-Path "IIS:\Sites\${testId}" | Should -Be $true
        sql-get-dbs | Where-Object { $_.Name.Contains($testId) } | Should -HaveCount 1
        existsInHostsFile -searchParam $proj.id | Should -Be $true
        tfs-get-workspaces $GLOBAL:sf.Config.tfsServerName | Where-Object { $_ -like "*$testId*" } | Should -HaveCount 1

        sd-project-remove

        It "remove project from sf-dev" {
            $sitefinities = @(sd-project-getAll) | Where-Object { $_.id -eq $testId }
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

        It "Remove workspace" {
            tfs-get-workspaces $GLOBAL:sf.Config.tfsServerName | Where-Object { $_ -like "*$testId*" } | Should -HaveCount 0
        }
    }
}