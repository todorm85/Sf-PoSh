. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    
    Describe "Import" -Tags ("import") {
        [SfProject]$project = set-testProject
        sf-proj-import -displayName "test-import" -path $project.webAppPath
        [SfProject]$importedProject = sf-proj-getCurrent
        
        It "generate new id" {
            $importedProject.id | Should -Not -Be $project.id
        }
        It "use same db" {
            $importedProjectDbName = _getCurrentAppDbName -project $importedProject
            $sourceProjectDbName = _getCurrentAppDbName -project $project
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
