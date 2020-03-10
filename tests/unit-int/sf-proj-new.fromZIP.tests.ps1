. "${PSScriptRoot}\load.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "Creating project from ZIP should" {
        It "create site, add domain and set project properties correctly" {
            $suffix = generateRandomName
            $projName = $Global:fromZipProjectName + $suffix
            sd-project-new -displayName $projName -sourcePath "$PSScriptRoot\..\utils\files\Build\SitefinityWebApp.zip"

            $sitefinities = @(sd-project-getAll) | Where-Object { $_.displayName -eq $projName }
            $sitefinities | Should -HaveCount 1
            $createdSf = [SfProject]$sitefinities[0]
            $id = $createdSf.id

            $createdSf.branch | Should -BeNullOrEmpty
            $createdSf.solutionPath | Should -BeNullOrEmpty
            $createdSf.webAppPath | Should -Be "$($GLOBAL:sf.Config.projectsDirectory)\${id}"
            $createdSf.websiteName | Should -Be $id

            Test-Path "$($GLOBAL:sf.Config.projectsDirectory)\${id}\SitefinityWebApp.csproj" | Should -Be $true
            Test-Path "IIS:\AppPools\${id}" | Should -Be $true
            Test-Path "IIS:\Sites\${id}" | Should -Be $true
            existsInHostsFile -searchParam $projName | Should -Be $true

            sd-project-remove -context $createdSf

            $suffix = generateRandomName
            $projName = $Global:fromZipProjectName + $suffix
            sd-project-new -displayName $projName -sourcePath "$PSScriptRoot\..\utils\files\Build\SitefinitySource.zip"
            $sitefinities = @(sd-project-getAll) | Where-Object { $_.displayName -eq $projName }
            $createdSf = [SfProject]$sitefinities[0]
            $createdSf.solutionPath | Should -Be "$($GLOBAL:sf.Config.projectsDirectory)\${id}"
            $createdSf.webAppPath | Should -Be "$($GLOBAL:sf.Config.projectsDirectory)\${id}/SitefinityWebApp"

            sd-project-remove -context $createdSf
        }
    }
}
