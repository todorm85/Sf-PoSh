. "$PSScriptRoot\init.ps1"

. "$testUtilsDir\load-module.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    Describe "Creating project from build location" {
        It "create site, add domain and set project properties correctly" {
            $projName = generateRandomName
            $Global:sf.project.Create($projName, "$PSScriptRoot\files\Build")

            $sitefinities = @(_sfData-get-allProjects) | Where-Object { $_.displayName -eq $projName }
            $sitefinities | Should -HaveCount 1
            $createdSf = [SfProject]$sitefinities[0]
            $id = $createdSf.id

            $createdSf.branch | Should -BeNullOrEmpty
            $createdSf.solutionPath | Should -BeNullOrEmpty
            $createdSf.webAppPath | Should -Be "$($Script:projectsDirectory)\${id}"
            $createdSf.websiteName | Should -Be $id

            Test-Path "$($Script:projectsDirectory)\${id}\SitefinityWebApp.csproj" | Should -Be $true
            Test-Path "IIS:\AppPools\${id}" | Should -Be $true
            Test-Path "IIS:\Sites\${id}" | Should -Be $true
            existsInHostsFile -searchParam $projName | Should -Be $true
        }
    }

    Describe "Starting new project from scratch should" -Tags ("create") {
        $projName = $null
        
        It "when creating the project from branch get latest, make workspace, site, domain, app pool permissions" {
            $projName = generateRandomName
            $Global:sf.project.Create($projName, '$/CMS/Sitefinity 4.0/Code Base')

            $sitefinities = @(_sfData-get-allProjects) | Where-Object { $_.displayName -eq $projName }
            $sitefinities | Should -HaveCount 1
            $createdSf = [SfProject]$sitefinities[0]
            $id = $createdSf.id

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
            $Global:sf.solution.Build()
        }
        It "start the app correctly" {
            $Global:sf.webApp.ResetApp()
            $url = get-appUrl
            $result = _invoke-NonTerminatingRequest $url
            $result | Should -Be 200

            # update the test project only if the newly created was successful
            [SfProject[]]$projects = _sfData-get-allProjects
            if (!$Global:testProjectDisplayName) {
                Write-Warning "e2e test project name not set, skipping clean."
                return
            }

            foreach ($proj in $projects) {
                if ($proj.displayName -ne $projName) {
                    sf-delete-project -context $proj -noPrompt
                }
            }

            foreach ($proj in $projects) {
                if ($proj.displayName -eq $projName) {
                    sf-rename-project -project $proj -newName $Global:testProjectDisplayName
                }
            }
        }
    }
}