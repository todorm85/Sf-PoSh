. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    
    Describe "Use existing" {
        [SfProject]$project = set-testProject
        $sourceProjectDbName = _sf-app-db-getName -appPath $project.webAppPath

        sf-proj-new -displayName "test-use-existing" -sourcePath $project.webAppPath
        
        [SfProject]$importedProject = sf-proj-getCurrent
        
        It "generate new id" {
            $importedProject.id | Should -Not -Be $project.id
        }
        It "use same db" {
            $importedProjectDbName = _sf-app-db-getName -appPath $importedProject.webAppPath
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
