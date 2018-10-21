. "${PSScriptRoot}\..\Infrastructure\load-module.ps1"

InModuleScope sf-dev {
    . "${PSScriptRoot}\..\Infrastructure\test-util.ps1"

    function set-testProject {
        $allProjects = @(_sfData-get-allProjects)
        if ($allProjects.Count -gt 0) {
            $proj = $allProjects[$allProjects.Count - 1]
            set-currentProject $proj
        }
        else {
            throw "no available projects";
        }
    
        return $proj
    }
    
    Describe "sf-new-project should" {
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
            _sql-load-module
            $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
            $sqlServer.Logins | Where-Object {$_.Name.Contains($id)} | Should -HaveCount 1
        }
    }

    Describe "start-app should" {
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

    Describe "sf-reset-app should" {
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

    Describe "states should" {
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

    Describe "clone should" {
        It "clone project" {
            set-testProject
            [SfProject]$sourceProj = _get-selectedProject
            $sourceName = $sourceProj.displayName
            $cloneTestName = "$sourceName-clone"

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
            _sql-load-module
            $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
            $sqlServer.Logins | Where-Object {$_.Name.Contains($cloneTestId)} | Should -HaveCount 1
        }
    }

    Describe "delete should" {
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
            _sql-load-module
            $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
            $sqlServer.Logins | Where-Object {$_.Name.Contains($testId)} | Should -HaveCount 0
            sql-get-dbs | Where-Object {$_.Name.Contains($testId)} | Should -HaveCount 0
        }
    }
}
