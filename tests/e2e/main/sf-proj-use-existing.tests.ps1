. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    Describe "Use existing" {
        [SfProject]$project = set-testProject
        $sourceProjectDbName = _db-getNameFromDataConfig -appPath $project.webAppPath

        sd-project-create -displayName "test-use-existing" -sourcePath $project.webAppPath

        [SfProject]$importedProject = sd-project-getCurrent

        It "generate new id" {
            $importedProject.id | Should -Not -Be $project.id
        }
        It "use same db" {
            $importedProjectDbName = _db-getNameFromDataConfig -appPath $importedProject.webAppPath
            $importedProjectDbName | Should -Be $sourceProjectDbName
            $importedProjectDbName | Should -Not -BeNullOrEmpty
        }
        It "use same directory" {
            $importedProject.webAppPath | Should -Not -BeNullOrEmpty
            $importedProject.webAppPath | Should -Be $project.webAppPath
        }
        It "use existing website" {
            $importedProject.websiteName | Should -Be $project.websiteName

            $siteExists = @(Get-Website | ? { $_.name -eq $importedProject.websiteName }).Count -gt 0
            $siteExists | Should -Be $true
        }
    }
}
