. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    Describe "when creating the project from branch" {
        initialize-testEnvironment
        sd-project-create -displayName $Global:testProjectDisplayName -sourcePath '$/CMS/Sitefinity 4.0/Code Base'

        $sitefinities = @(sd-project-getAll) | Where-Object { $_.displayName -eq $Global:testProjectDisplayName }
        $sitefinities | Should -HaveCount 1
        $createdSf = [SfProject]$sitefinities[0]
        $id = $createdSf.id

        It "Set project data correctly" {
            $createdSf.branch | Should -Be '$/CMS/Sitefinity 4.0/Code Base'
            $createdSf.solutionPath | Should -Be "$($GLOBAL:sf.Config.projectsDirectory)\${id}"
            $createdSf.webAppPath | Should -Be "$($GLOBAL:sf.Config.projectsDirectory)\${id}\SitefinityWebApp"
            $createdSf.websiteName | Should -Be $id
        }

        It "Create project artefacts correctly" {
            Test-Path "$($GLOBAL:sf.Config.projectsDirectory)\$id\$($createdSf.displayName)($id).sln" | Should -Be $true
            Test-Path "$($GLOBAL:sf.Config.projectsDirectory)\$id\Telerik.Sitefinity.sln" | Should -Be $true
            Test-Path "IIS:\AppPools\${id}" | Should -Be $true
            Test-Path "IIS:\Sites\${id}" | Should -Be $true
            existsInHostsFile -searchParam $Global:testProjectDisplayName | Should -Be $true
        }
    }
}