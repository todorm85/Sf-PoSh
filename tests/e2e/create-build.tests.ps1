. "$PSScriptRoot\init.ps1"

. "$testUtilsDir\load-module.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    Describe "Creating project from build location should" -Tags ("create-build") {
        It "create site, add domain and set project properties correctly" {
            $projName = generateRandomName
            $Global:sf.project.Create($projName, "$PSScriptRoot\files\Build")

            $sitefinities = @(sf-get-allProjects) | Where-Object { $_.displayName -eq $projName }
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
}