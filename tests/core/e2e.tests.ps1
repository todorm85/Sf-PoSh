. "${PSScriptRoot}\Infrastructure\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\Infrastructure\test-util.ps1"
    [SqlClient]$sql = _get-sqlClient

    Describe "Starting new project from scratch should" -Tags ("e2e") {
        It "when creating the project get latest, make workspace, site, domain, app pool permissions" {
            $projName = generateRandomName
            $Global:sf.Create($projName, '$/CMS/Sitefinity 4.0/Code Base')

            $sitefinities = @(_sfData-get-allProjects) | Where-Object { $_.displayName -eq $projName }
            $sitefinities | Should -HaveCount 1
            $createdSf = [SfProject]$sitefinities[0]
            $id = $createdSf.id

            $createdSf.containerName | Should -Be ''
            $createdSf.branch | Should -Be '$/CMS/Sitefinity 4.0/Code Base'
            $createdSf.solutionPath | Should -Be "$($Script:projectsDirectory)\${id}"
            $createdSf.webAppPath | Should -Be "$($Script:projectsDirectory)\${id}\SitefinityWebApp"
            $createdSf.websiteName | Should -Be $id

            Test-Path "$($Script:projectsDirectory)\${id}\$($createdSf.displayName)($($createdSf.id)).sln" | Should -Be $true
            Test-Path "$($Script:projectsDirectory)\${id}\Telerik.Sitefinity.sln" | Should -Be $true
            Test-Path "IIS:\AppPools\${id}" | Should -Be $true
            Test-Path "IIS:\Sites\${id}" | Should -Be $true
            existsInHostsFile -searchParam $projName | Should -Be $true
        }
        It "when building succeed after at least 3 retries" {
            set-testProject
            $Global:sf.solution.Build()
        }
    }

    Describe "Resetting app should" -Tags ("e2e") {
        [SfProject]$project = set-testProject
        $testId = $project.id
        sf-reset-app -start -force

        $configsPath = "$($Script:projectsDirectory)\${testId}\SitefinityWebApp\App_Data\Sitefinity\Configuration"
        Test-Path $configsPath | Should -Be $true
        $dbName = sf-get-appDbName
        $dbName | Should -Not -BeNullOrEmpty

        sf-reset-app

        It "remove app data and database" {            
            $sql.GetDbs() | Where-Object {$_.Name.Contains($dbName)} | Should -HaveCount 0
            Test-Path $configsPath | Should -Be $false            
        }

        It "start the app correctly again after deletion of data and database" {
            $Global:sf.webApp.ResetApp()
            $url = get-appUrl
            $result = _invoke-NonTerminatingRequest $url
            $result | Should -Be 200
        }
    }

    Describe "States should" -Tags ("e2e") {
        It "save and then restore app_data folder and database" {
            set-testProject
            [SfProject]$project = _get-selectedProject
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
    
    Describe "Clone should" -Tags ("e2e") {
        It "create new project with separate workspace, site, database." {
            [SfProject]$sourceProj = set-testProject
            $sourceName = $sourceProj.displayName
            $cloneTestName = "$sourceName-clone"
            $sql.GetDbs() | Where-Object {$_.name -eq $sourceProj.id} | Should -HaveCount 1

            # edit a file in source project
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

            $Global:sf.Clone()

            $sitefinities = @(_sfData-get-allProjects) | Where-Object { $_.displayName -eq $cloneTestName }
            $sitefinities | Should -HaveCount 1
            [SfProject]$project = $sitefinities[0]
            $cloneTestId = $project.id
            $project.containerName | Should -Be ''
            $project.branch | Should -Be '$/CMS/Sitefinity 4.0/Code Base'
            $project.solutionPath | Should -Be "$($Script:projectsDirectory)\${cloneTestId}"
            $project.webAppPath | Should -Be "$($Script:projectsDirectory)\${cloneTestId}\SitefinityWebApp"
            $project.websiteName | Should -Be $cloneTestId
            existsInHostsFile -searchParam $project.displayName | Should -Be $true
            Test-Path "$($Script:projectsDirectory)\${cloneTestId}\$($project.displayName)($($project.id)).sln" | Should -Be $true
            Test-Path "$($Script:projectsDirectory)\${cloneTestId}\Telerik.Sitefinity.sln" | Should -Be $true
            Test-Path "IIS:\AppPools\${cloneTestId}" | Should -Be $true
            Test-Path "IIS:\Sites\${cloneTestId}" | Should -Be $true
            $sql.GetDbs() | Where-Object {$_.name -eq $cloneTestId} | Should -HaveCount 1
            tfs-get-branchPath -path $project.solutionPath | Should -Not -Be $null
        }
    }

    Describe "Rename should" -Tags ("e2e") {
        It "change the display name and domain" {
            [SfProject]$testProject = set-testProject
            $id = $testProject.id
            $oldName = $testProject.displayName
            $newName = generateRandomName

            existsInHostsFile -searchParam $newName | Should -Be $false
            Test-Path "$($Script:projectsDirectory)\$id\$newName($id).sln" | Should -Be $false
            existsInHostsFile -searchParam $newName | Should -Be $false

            $Global:sf.Rename($newName)
            
            existsInHostsFile -searchParam $newName | Should -Be $true
            existsInHostsFile -searchParam $oldName | Should -Be $false
            Test-Path "$($Script:projectsDirectory)\$id\$newName($id).sln" | Should -Be $true
            Test-Path "$($Script:projectsDirectory)\$id\$oldName($id).sln" | Should -Be $false
            ([string](get-appUrl)).IndexOf($newName) | Should -BeGreaterThan -1
        }
    }

    Describe "Subapp functionality should" -Tags ("e2e") {
        [SfProject]$project = set-testProject
        $subApp = "subApp"
        $site = $project.websiteName
        $pool = iis-get-siteAppPool -websiteName $site

        It "create application and set its path and app pool" {
            $Global:sf.IIS.SetupSubApp($subApp)
            Test-Path "IIS:\Sites\$site\$subApp" | Should -Be $true
            (Get-Item -Path "IIS:\Sites\$site\$subApp").applicationPool | Should -Be $pool
            (Get-Item -Path "IIS:\Sites\$site").physicalPath | Should -Not -Be $project.webAppPath
        }
        It "return the correct url for subapp" {
            $res = get-appUrl
            $res.EndsWith($subApp) | Should -Be $true
        }
        It "remove sub app by deleting the application and setting the site path" {
            $Global:sf.IIS.RemoveSubApp()
            Test-Path "IIS:\Sites\$site\$subApp" | Should -Be $false
            (Get-Item -Path "IIS:\Sites\$site").physicalPath | Should -Be $project.webAppPath
        }
        It "build the correct url after subapp removal" {
            $res = get-appUrl
            $res.EndsWith($subApp) | Should -Not -Be $true
        }
    }
    
    Describe "Delete should" -Tags ("e2e", "delete") {
        It "remove all" {
            [SfProject]$proj = set-testProject
            $testId = $proj.id
            
            $Global:sf.Delete()
            
            $sitefinities = @(_sfData-get-allProjects) | where {$_.id -eq $testId}
            $sitefinities | Should -HaveCount 0
            Test-Path "$($Script:projectsDirectory)\${testId}" | Should -Be $false
            Test-Path "IIS:\AppPools\${testId}" | Should -Be $false
            Test-Path "IIS:\Sites\${testId}" | Should -Be $false
            $sql.GetDbs() | Where-Object {$_.Name.Contains($testId)} | Should -HaveCount 0
            existsInHostsFile -searchParam $proj.displayName | Should -Be $false
        }
    }
}