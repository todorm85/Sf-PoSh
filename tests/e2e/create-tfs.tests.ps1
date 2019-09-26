. "$PSScriptRoot\init.ps1"

. "$testUtilsDir\load-module.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    Describe "Creating project from TFS branch should" -Tags ("create-tfs") {
        $projName = generateRandomName
        function Set-TestProject {
            $sitefinities = @(data-getAllProjects)
            $context = $sitefinities[$sitefinities.Count - 1]
            proj-setCurrent -newContext $context
        }

        It "when creating the project from branch get latest, make workspace, site, domain, app pool permissions" {
            proj-new -displayName $projName -sourcePath '$/CMS/Sitefinity 4.0/Code Base'

            $sitefinities = @(data-getAllProjects) | Where-Object { $_.displayName -eq $projName }
            $sitefinities | Should -HaveCount 1
            $createdSf = [SfProject]$sitefinities[0]
            $id = $createdSf.id

            $createdSf.branch | Should -Be '$/CMS/Sitefinity 4.0/Code Base'
            $createdSf.solutionPath | Should -Be "$($GLOBAL:Sf.Config.projectsDirectory)\${id}"
            $createdSf.webAppPath | Should -Be "$($GLOBAL:Sf.Config.projectsDirectory)\${id}\SitefinityWebApp"
            $createdSf.websiteName | Should -Be $id

            Test-Path "$($GLOBAL:Sf.Config.projectsDirectory)\${id}\$($createdSf.displayName)($($createdSf.id)).sln" | Should -Be $true
            Test-Path "$($GLOBAL:Sf.Config.projectsDirectory)\${id}\Telerik.Sitefinity.sln" | Should -Be $true
            Test-Path "IIS:\AppPools\${id}" | Should -Be $true
            Test-Path "IIS:\Sites\${id}" | Should -Be $true
            existsInHostsFile -searchParam $projName | Should -Be $true
        }
        It "when building succeed after at least 3 retries" {
            Set-TestProject
            sol-build -retryCount 3
        }
        It "start the app correctly" {
            Set-TestProject
            app-reset -start
            $url = _getAppUrl
            $result = _invokeNonTerminatingRequest $url
            $result | Should -Be 200

            # update the test project only if the newly created was successful
            [SfProject[]]$projects = data-getAllProjects
            if (!$Global:testProjectDisplayName) {
                Write-Warning "e2e test project name not set, skipping clean."
                return
            }

            foreach ($proj in $projects) {
                if ($proj.displayName -ne $projName) {
                    proj-remove -context $proj -noPrompt
                }
            }

            foreach ($proj in $projects) {
                if ($proj.displayName -eq $projName) {
                    proj-rename -project $proj -newName $Global:testProjectDisplayName
                }
            }
        }
    }
}
