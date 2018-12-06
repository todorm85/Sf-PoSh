. "${PSScriptRoot}\..\Infrastructure\load-module.ps1"

InModuleScope sf-dev {
    . "${PSScriptRoot}\..\Infrastructure\test-util.ps1"

    function set-testProject {
        Param(
            [switch]$oldest
        )

        $allProjects = @(_sfData-get-allProjects)
        if ($allProjects.Count -gt 0) {
            $i = if ($oldest) {0} else {$allProjects.Count - 1}
            $proj = $allProjects[$i]
            set-currentProject $proj
        }
        else {
            throw "no available projects";
        }
    
        return $proj
    }

    Describe "sf-new-project should" -Tags ("e2e", "essential", "new") {
        It "create and build project" {
            $projName = [System.Guid]::NewGuid().ToString().Replace('-', '_')
            sf-new-project -displayName $projName -predefinedBranch '$/CMS/Sitefinity 4.0/Code Base' -buildSolution
            $sitefinities = @(_sfData-get-allProjects) | Where-Object { $_.displayName -eq $projName }
            $sitefinities | Should -HaveCount 1
            $sf = [SfProject]$sitefinities[0]
            $id = $sf.id

            $sf.containerName | Should -Be ''
            $sf.branch | Should -Be '$/CMS/Sitefinity 4.0/Code Base'
            $sf.solutionPath | Should -Be "$($Script:projectsDirectory)\${id}"
            $sf.webAppPath | Should -Be "$($Script:projectsDirectory)\${id}\SitefinityWebApp"
            $sf.websiteName | Should -Be $id

            Test-Path "$($Script:projectsDirectory)\${id}\$($sf.displayName)($($sf.id)).sln" | Should -Be $true
            Test-Path "$($Script:projectsDirectory)\${id}\Telerik.Sitefinity.sln" | Should -Be $true
            Test-Path "IIS:\AppPools\${id}" | Should -Be $true
            Test-Path "IIS:\Sites\${id}" | Should -Be $true
            $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
            $sqlServer.Logins | Where-Object {$_.Name.Contains($id)} | Should -HaveCount 1
        }
    } 

    Describe "start-app should" -Tags ("e2e", "essential", "start") {
        It "start Sitefinity" {
            set-testProject
            # even after successful build we need to build once more to have a working app
            sf-build-solution
            create-startupConfig
            start-app
            $url = get-appUrl
            $result = _invoke-NonTerminatingRequest $url
            $result | Should -Be 200
        }
    }  

    Describe "sf-reset-app should" -Tags ("e2e", "essential", "reset") {
        It "reset Sitefinity" {
            [SfProject]$project = set-testProject
            $testId = $project.id
            $configsPath = "$($Script:projectsDirectory)\${testId}\SitefinityWebApp\App_Data\Sitefinity\Configuration"
            Test-Path $configsPath | Should -Be $true
            sf-reset-app
            sql-get-dbs | Where-Object {$_.Name.Contains($testId)} | Should -HaveCount 0
            Test-Path $configsPath | Should -Be $false
            sf-reset-app -start
            $url = get-appUrl
            $result = _invoke-NonTerminatingRequest $url
            $result | Should -Be 200
        }
    }

    Describe "states should" -Tags ("e2e", "secondary", "states") {
        It "save and then restore state" {
            set-testProject
            [SfProject]$project = _get-selectedProject
            $configsPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
            [string]$stateName = [System.Guid]::NewGuid().ToString()
            $stateName = $stateName.Replace('-', '_')
            # $statePath = "$($Script:globalContext.webAppPath)/sf-dev-tool/states/$stateName"

            $beforeSaveFilePath = "$configsPath\before_$stateName"
            New-Item $beforeSaveFilePath
            
            sf-new-appState $stateName
            
            # Test-Path "$statePath\$dbName.bak" | Should -BeTrue
            $afterSaveFilePath = "$configsPath\after_$stateName"
            New-Item $afterSaveFilePath
            Remove-Item -Path $beforeSaveFilePath
            $dbName = sf-get-appDbName
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

    Describe "clone should" -Tags ("e2e", "secondary", "clone") {
        It "clone project" {
            [SfProject]$sourceProj = set-testProject
            $sourceName = $sourceProj.displayName
            $cloneTestName = "$sourceName-clone"

            # edit a file in source project
            $webConfigPath = "$($sourceProj.webAppPath)\web.config"
            tfs-checkout-file $webConfigPath
            [xml]$xmlData = Get-Content $webConfigPath
            [System.Xml.XmlElement]$appSettings = $xmlData.configuration.appSettings
            $newElement = $xmlData.CreateElement("add")
            $testKeyName = [Guid]::NewGuid().ToString()
            $newElement.SetAttribute("key", $testKeyName)
            $newElement.SetAttribute("value", "testing")
            $appSettings.AppendChild($newElement)
            $xmlData.Save($webConfigPath)

            sf-clone-project

            $sitefinities = @(_sfData-get-allProjects) | Where-Object { $_.displayName -eq $cloneTestName }
            $sitefinities | Should -HaveCount 1
            [SfProject]$sf = $sitefinities[0]
            $cloneTestId = $sf.id
            $sf.containerName | Should -Be ''
            $sf.branch | Should -Be '$/CMS/Sitefinity 4.0/Code Base'
            $sf.solutionPath | Should -Be "$($Script:projectsDirectory)\${cloneTestId}"
            $sf.webAppPath | Should -Be "$($Script:projectsDirectory)\${cloneTestId}\SitefinityWebApp"
            $sf.websiteName | Should -Be $cloneTestId

            Test-Path "$($Script:projectsDirectory)\${cloneTestId}\$($sf.displayName)($($sf.id)).sln" | Should -Be $true
            Test-Path "$($Script:projectsDirectory)\${cloneTestId}\Telerik.Sitefinity.sln" | Should -Be $true
            Test-Path "IIS:\AppPools\${cloneTestId}" | Should -Be $true
            Test-Path "IIS:\Sites\${cloneTestId}" | Should -Be $true
            $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
            $sqlServer.Logins | Where-Object {$_.Name.Contains($cloneTestId)} | Should -HaveCount 1
        }
    }

    Describe "delete should" -Tags ("e2e", "essential", "delete") {
        It "delete project" {
            [SfProject]$proj = set-testProject
            $testId = $proj.id
            stop-allMsbuild
            iisreset.exe
            sf-delete-project -noPrompt
            
            $sitefinities = @(_sfData-get-allProjects) | where {$_.id -eq $testId}
            $sitefinities | Should -HaveCount 0
            Test-Path "$($Script:projectsDirectory)\${testId}" | Should -Be $false
            Test-Path "IIS:\AppPools\${testId}" | Should -Be $false
            Test-Path "IIS:\Sites\${testId}" | Should -Be $false
            $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
            $sqlServer.Logins | Where-Object {$_.Name.Contains($testId)} | Should -HaveCount 0
            sql-get-dbs | Where-Object {$_.Name.Contains($testId)} | Should -HaveCount 0
        }
    } 
}