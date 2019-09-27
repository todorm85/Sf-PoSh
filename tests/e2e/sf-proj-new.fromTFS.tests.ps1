. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    It "when creating the project from branch get latest, make workspace, site, domain, app pool permissions" {
        initialize-testEnvironment
        sf-proj-new -displayName $Global:testProjectDisplayName -sourcePath '$/CMS/Sitefinity 4.0/Code Base'

        $sitefinities = @(sf-data-getAllProjects) | Where-Object { $_.displayName -eq $Global:testProjectDisplayName }
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
        existsInHostsFile -searchParam $Global:testProjectDisplayName | Should -Be $true
    }
}
