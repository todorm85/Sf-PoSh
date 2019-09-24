. "$PSScriptRoot\init.ps1"

. "$testUtilsDir\load-module.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    
    Describe "Import" -Tags ("import") {
        [SfProject]$project = set-testProject
        import-project -displayName "test-import" -path $project.webAppPath
        [SfProject]$importedProject = get-currentProject
        
        It "generate new id" {
            $importedProject.id | Should -Not -Be $project.id
        }
        It "use same db" {
            $importedProjectDbName = _get-currentAppDbName -project $importedProject
            $sourceProjectDbName = _get-currentAppDbName -project $project
            $importedProjectDbName | Should -Be $sourceProjectDbName
            $importedProjectDbName | Should -Not -BeNullOrEmpty
        }
        It "use same directory" {
            $importedProject.webAppPath | Should -Not -BeNullOrEmpty
            $importedProject.webAppPath | Should -Be $project.webAppPath
        }
        It "use existing website" {
            $importedProject.websiteName | Should -Be $project.websiteName
            iis-test-isSiteNameDuplicate -name $importedProject.websiteName | Should -Be $true
        }
    }
}