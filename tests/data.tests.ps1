Import-Module sf-dev

InModuleScope sf-dev {
    . "${PSScriptRoot}\init-tests.ps1"
    
    Describe "_sfData-get-allProjects should" {
        It "return empty collection when no projects" {
            $projects = _sfData-get-allProjects
            $projects | Should -HaveCount 0
        }
        It "return correct count of projects" {
            $proj1 = New-Object SfProject -Property @{
                branch = "test-branch";
                containerName = "test-container";
                id = "id1";
            }

            _sfData-save-project -context $proj1
            [SfProject[]]$projects = _sfData-get-allProjects
            $projects | Should -HaveCount 1
            $projects[0].id | Should -Be "id1"
            $projects[0].branch | Should -Be "test-branch"
            $projects[0].containerName | Should -Be "test-container"
        }

        clean-testDb
    } -Tag "Unit"
}