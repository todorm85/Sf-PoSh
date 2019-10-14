. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    Describe "Creating project from ZIP should" {
        It "create site, add domain and set project properties correctly" {
            $suffix = generateRandomName
            $projName = $Global:fromZipProjectName + $suffix
            sf-proj-new -displayName $projName -sourcePath "$PSScriptRoot\..\test-utils\files\Build\SitefinityWebApp.zip"

            $sitefinities = @(sf-data-getAllProjects) | Where-Object { $_.displayName -eq $projName }
            $sitefinities | Should -HaveCount 1
            $createdSf = [SfProject]$sitefinities[0]
            $id = $createdSf.id

            $createdSf.branch | Should -BeNullOrEmpty
            $createdSf.solutionPath | Should -BeNullOrEmpty
            $createdSf.webAppPath | Should -Be "$($GLOBAL:Sf.Config.projectsDirectory)\${id}"
            $createdSf.websiteName | Should -Be $id

            Test-Path "$($GLOBAL:Sf.Config.projectsDirectory)\${id}\SitefinityWebApp.csproj" | Should -Be $true
            Test-Path "IIS:\AppPools\${id}" | Should -Be $true
            Test-Path "IIS:\Sites\${id}" | Should -Be $true
            existsInHostsFile -searchParam $projName | Should -Be $true
        }
    }
}
