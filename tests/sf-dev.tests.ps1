Import-Module sf-dev

InModuleScope sf-dev {
    . "${PSScriptRoot}\init-tests.ps1"
    $testId = "${baseTestId}0"
    
    Describe "sf-dev should" {
        It "create project correctly" {
            sf-new-project -displayName 'test1' -predefinedBranch '$/CMS/Sitefinity 4.0/Code Base'
            $sitefinities = @(_sfData-get-allProjects) | Where-Object { $_.id -eq $testId }
            $sitefinities | Should -HaveCount 1
            $sf = $sitefinities[0]
            $sf.displayName | Should -Be 'test1'
            $sf.containerName | Should -Be ''
            $sf.branch | Should -Be '$/CMS/Sitefinity 4.0/Code Base'
            $sf.solutionPath | Should -Be "$($Script:projectsDirectory)\${testId}"
            $sf.webAppPath | Should -Be "$($Script:projectsDirectory)\${testId}\SitefinityWebApp"
            $sf.websiteName | Should -Be $testId

            Test-Path "$($Script:projectsDirectory)\${testId}\$($sf.displayName)($($sf.id)).sln" | Should -Be $true
            Test-Path "$($Script:projectsDirectory)\${testId}\Telerik.Sitefinity.sln" | Should -Be $true
            Test-Path "IIS:\AppPools\${testId}" | Should -Be $true
            Test-Path "IIS:\Sites\${testId}" | Should -Be $true
            _sql-load-module
            $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
            $sqlServer.Logins | Where-Object {$_.Name.Contains($testId)} | Should -HaveCount 1
        }

        It "build and start Sitefinity" {
            function build {
                sf-build-solution
            }

            # solution order is broken so we need to build it several times
            $tries = 0
            try {
                build    
            }
            catch {
                $tries++
                if ($tries -le 3) {
                    build
                }
                else {
                    throw "Could not build sitefinity after $tries tries."
                }
            }

            # even after successful build we need to build once more to have a working app
            build

            create-startupConfig
            start-app
            $url = get-appUrl
            $result = _invoke-NonTerminatingRequest $url
            $result | Should -Be 200
        }

        It "resets Sitefinity" {
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

        It "clone project correctly" {
            sf-clone-project
            $cloneTestId = "${baseTestId}1"

            $sitefinities = @(_sfData-get-allProjects) | Where-Object { $_.id -eq $cloneTestId }
            $sitefinities | Should -HaveCount 1
            [SfProject]$sf = $sitefinities[0]
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

        It "delete project correctly" {
            stop-allMsbuild
            iisreset.exe
            $Script:globalContext = @(_sfData-get-allProjects) | where {$_.id -eq $testId }
            delete-project -noPrompt

            $sitefinities = @(_sfData-get-allProjects) | where {$_.id -eq $testId }
            $sitefinities | Should -HaveCount 0
            Test-Path "$($Script:projectsDirectory)\${testId}" | Should -Be $false
            Test-Path "IIS:\AppPools\${testId}" | Should -Be $false
            Test-Path "IIS:\Sites\${testId}" | Should -Be $false
            _sql-load-module
            $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
            $sqlServer.Logins | Where-Object {$_.Name.Contains($testId)} | Should -HaveCount 0
            sql-get-dbs | Where-Object {$_.Name.Contains($testId)} | Should -HaveCount 0
        }
    } -Tag "e2e"

    clean-testAll
}
