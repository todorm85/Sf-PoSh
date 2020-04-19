. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {

    Describe "Creating project from ZIP should" {
        It "create site, add domain and set project properties correctly" {
            $suffix = generateRandomName
            $projName = $Global:fromZipProjectName + $suffix
            sf-project-new -displayName $projName -sourcePath "$PSScriptRoot\..\utils\files\Build\SitefinityWebApp.zip"

            $sitefinities = @(sf-project-getAll) | Where-Object { $_.displayName -eq $projName }
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

            sf-project-remove -context $createdSf

            $suffix = generateRandomName
            $projName = $Global:fromZipProjectName + $suffix
            New-Item "$PSScriptRoot\..\utils\files\Build\Sitefinity.lic" -Force
            sf-project-new -displayName $projName -sourcePath "$PSScriptRoot\..\utils\files\Build\SitefinitySource.zip"
            $sitefinities = @(sf-project-getAll) | Where-Object { $_.displayName -eq $projName }
            $createdSf = [SfProject]$sitefinities[0]
            $createdSf.solutionPath | Should -Be "$($GLOBAL:sf.Config.projectsDirectory)\${id}"
            $createdSf.webAppPath | Should -Be "$($GLOBAL:sf.Config.projectsDirectory)\${id}\SitefinityWebApp"
            Test-Path "$($createdSf.webAppPath)\App_Data\Sitefinity\Sitefinity.lic" | Should -BeTrue
            Remove-Item "$PSScriptRoot\..\utils\files\Build\Sitefinity.lic"

            sf-project-remove -context $createdSf
        }
    }
}
