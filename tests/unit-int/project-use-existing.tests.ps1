. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {

    Describe "Use existing" {
        InTestProjectScope {
        [SfProject]$project = sf-project-get
        $sourceProjectDbName = _db-getNameFromDataConfig -appPath $project.webAppPath

        sf-project-new -displayName "test-use-existing" -sourcePath $project.webAppPath

        [SfProject]$importedProject = sf-project-get

        It "save the new project in sfdev db" {
            _data-getAllProjects | Should -HaveCount 2
        }

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
}
