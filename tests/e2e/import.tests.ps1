. "$PSScriptRoot\init.ps1"

. "$testUtilsDir\load-module.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    
    Describe "Import" -Tags ("import") {
        [SfProject]$project = set-testProject
        $sf.project.Import("test-import", $project.webAppPath)
        [SfProject]$importedProject = _get-selectedProject
        
        It "generate new id" {
            $importedProject.id | Should -Not -Be $project.id
        }
        It "use same db" {
            $importedProjectDbName = get-currentAppDbName -project $importedProject
            $sourceProjectDbName = get-currentAppDbName -project $project
            $importedProjectDbName | Should -Be $sourceProjectDbName
            $importedProjectDbName | Should -Not -BeNullOrEmpty
        }
        It "use same directory" {
            $importedProject.webAppPath | Should -Not -BeNullOrEmpty
            $importedProject.webAppPath | Should -Be $project.webAppPath
        }
        It "create new website using the id" {
            $importedProject.websiteName | Should -Be $importedProject.id
            iis-test-isSiteNameDuplicate -name $importedProject.websiteName | Should -Be $true
        }
    }
}