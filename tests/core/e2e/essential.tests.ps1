. "${PSScriptRoot}\..\Infrastructure\load-module.ps1"

InModuleScope sf-dev.dev {
    . "$PSScriptRoot\..\Infrastructure\test-util.ps1"
    
    Describe "Starting new project from scratch should" -Tags ("e2e") {
        It "when creating the project get latest, make workspace, site, domain, app pool permissions" {
            $projName = generateRandomName
            sf-new-project -displayName $projName -predefinedBranch '$/CMS/Sitefinity 4.0/Code Base'
            $sitefinities = @(_sfData-get-allProjects) | Where-Object { $_.displayName -eq $projName }
            $sitefinities | Should -HaveCount 1
            $sf = [SfProject]$sitefinities[0]
            $id = $sf.id

            $sf.containerName | Should -Be ''
            $sf.branch | Should -Be '$/CMS/Sitefinity 4.0/Code Base'
            $sf.solutionPath | Should -Be "$($Global:projectsDirectory)\${id}"
            $sf.webAppPath | Should -Be "$($Global:projectsDirectory)\${id}\SitefinityWebApp"
            $sf.websiteName | Should -Be $id

            Test-Path "$($Global:projectsDirectory)\${id}\$($sf.displayName)($($sf.id)).sln" | Should -Be $true
            Test-Path "$($Global:projectsDirectory)\${id}\Telerik.Sitefinity.sln" | Should -Be $true
            Test-Path "IIS:\AppPools\${id}" | Should -Be $true
            Test-Path "IIS:\Sites\${id}" | Should -Be $true
            $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
            $sqlServer.Logins | Where-Object {$_.Name.Contains($id)} | Should -HaveCount 1
            existsInHostsFile -searchParam $projName | Should -Be $true
        }
        It "when building succeed after at least 3 retries" {
            set-testProject
            sf-build-solution -retryCount 3
        }
        It "when starting should receive 200 or 503 after attempt to access the backend, then 200 for appstatus page for a while, then 404 for appstatus, then 200 for backend request." {
            set-testProject
            sf-reset-app -start
            $url = get-appUrl
            $result = _invoke-NonTerminatingRequest $url
            $result | Should -Be 200
        }
    }

    Describe "Resetting app should" -Tags ("e2e") {
        [SfProject]$project = set-testProject
        $testId = $project.id
        $configsPath = "$($Global:projectsDirectory)\${testId}\SitefinityWebApp\App_Data\Sitefinity\Configuration"
        Test-Path $configsPath | Should -Be $true
        $dbName = sf-get-appDbName
        $dbName | Should -Not -BeNullOrEmpty

        sf-reset-app

        It "remove app data and database" {            
            sql-get-dbs | Where-Object {$_.Name.Contains($dbName)} | Should -HaveCount 0
            Test-Path $configsPath | Should -Be $false
            sf-reset-app -start
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
            # $statePath = "$($Global:globalContext.webAppPath)/sf-dev-tool/states/$stateName"

            $beforeSaveFilePath = "$configsPath\before_$stateName"
            New-Item $beforeSaveFilePath
            
            sf-new-appState $stateName
            
            # Test-Path "$statePath\$dbName.bak" | Should -BeTrue
            $afterSaveFilePath = "$configsPath\after_$stateName"
            New-Item $afterSaveFilePath
            Remove-Item -Path $beforeSaveFilePath
            $dbName = sf-get-appDbName
            $dbName | Should -Not -BeNullOrEmpty
            sql-insert-items -dbName $dbName -tableName 'sf_xml_config_items' -columns "path, dta, last_modified, id" -values "'test', '<testConfigs/>', '$([System.DateTime]::Now.ToString())', '$([System.Guid]::NewGuid())'"
            $config = sql-get-items -dbName $dbName -tableName 'sf_xml_config_items' -selectFilter "dta" -whereFilter "dta = '<testConfigs/>'"
            $config | Should -Not -BeNullOrEmpty

            sf-restore-appState $stateName

            Test-Path $beforeSaveFilePath | Should -BeTrue
            Test-Path $afterSaveFilePath | Should -BeFalse
            $config = sql-get-items -dbName $dbName -tableName 'sf_xml_config_items' -selectFilter "dta" -whereFilter "dta = '<testConfigs/>'"
            $config | Should -BeNullOrEmpty
        }
    }
    Describe "Clone should" -Tags ("e2e") {
        It "create new project with separate workspace, site, database." {
            [SfProject]$sourceProj = set-testProject
            $sourceName = $sourceProj.displayName
            $cloneTestName = "$sourceName-clone"

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

            sf-clone-project

            $sitefinities = @(_sfData-get-allProjects) | Where-Object { $_.displayName -eq $cloneTestName }
            $sitefinities | Should -HaveCount 1
            [SfProject]$sf = $sitefinities[0]
            $cloneTestId = $sf.id
            $sf.containerName | Should -Be ''
            $sf.branch | Should -Be '$/CMS/Sitefinity 4.0/Code Base'
            $sf.solutionPath | Should -Be "$($Global:projectsDirectory)\${cloneTestId}"
            $sf.webAppPath | Should -Be "$($Global:projectsDirectory)\${cloneTestId}\SitefinityWebApp"
            $sf.websiteName | Should -Be $cloneTestId
            existsInHostsFile -searchParam $sf.displayName | Should -Be $true
            Test-Path "$($Global:projectsDirectory)\${cloneTestId}\$($sf.displayName)($($sf.id)).sln" | Should -Be $true
            Test-Path "$($Global:projectsDirectory)\${cloneTestId}\Telerik.Sitefinity.sln" | Should -Be $true
            Test-Path "IIS:\AppPools\${cloneTestId}" | Should -Be $true
            Test-Path "IIS:\Sites\${cloneTestId}" | Should -Be $true
            

            $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
            $sqlServer.Logins | Where-Object {$_.Name.Contains($cloneTestId)} | Should -HaveCount 1
        }
    }

    Describe "Rename should" -Tags ("e2e") {
        It "change the display name and domain" {
            [SfProject]$sf = set-testProject
            $id = $sf.id
            $oldName = $sf.displayName
            $newName = generateRandomName

            existsInHostsFile -searchParam $newName | Should -Be $false
            Test-Path "$($Global:projectsDirectory)\$id\$newName($id).sln" | Should -Be $false
            existsInHostsFile -searchParam $newName | Should -Be $false

            sf-rename-project -newName $newName
            
            existsInHostsFile -searchParam $newName | Should -Be $true
            existsInHostsFile -searchParam $oldName | Should -Be $false
            Test-Path "$($Global:projectsDirectory)\$id\$newName($id).sln" | Should -Be $true
            Test-Path "$($Global:projectsDirectory)\$id\$oldName($id).sln" | Should -Be $false
            ([string](get-appUrl)).IndexOf($newName) | Should -BeGreaterThan -1
        }
    }

    Describe "Subapp functionality should" -Tags ("e2e") {
        [SfProject]$project = set-testProject
        $subApp = "subApp"
        $site = $project.websiteName
        $pool = iis-get-siteAppPool -websiteName $site

        It "create application and set its path and app pool" {
            sf-setup-asSubApp -subAppName $subApp
            Test-Path "IIS:\Sites\$site\$subApp" | Should -Be $true
            (Get-Item -Path "IIS:\Sites\$site\$subApp").applicationPool | Should -Be $pool
            (Get-Item -Path "IIS:\Sites\$site").physicalPath | Should -Not -Be $project.webAppPath
        }
        It "return the correct url for subapp" {
            $res = get-appUrl
            $res.EndsWith($subApp) | Should -Be $true
        }
        It "remove sub app by deleting the application and setting the site path" {
            sf-remove-subApp
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
            stop-allMsbuild
            iisreset.exe
            sf-delete-project -noPrompt
            
            $sitefinities = @(_sfData-get-allProjects) | where {$_.id -eq $testId}
            $sitefinities | Should -HaveCount 0
            Test-Path "$($Global:projectsDirectory)\${testId}" | Should -Be $false
            Test-Path "IIS:\AppPools\${testId}" | Should -Be $false
            Test-Path "IIS:\Sites\${testId}" | Should -Be $false
            $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
            $sqlServer.Logins | Where-Object {$_.Name.Contains($testId)} | Should -HaveCount 0
            sql-get-dbs | Where-Object {$_.Name.Contains($testId)} | Should -HaveCount 0
            existsInHostsFile -searchParam $proj.displayName | Should -Be $false
        }
    }
}