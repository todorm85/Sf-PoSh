. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "sf-get-allProjects" {
        Mock _initialize-project { }

        It "return empty collection when no projects" {
            $projects = sf-get-allProjects
            $projects | Should -HaveCount 0
        }

        It "return correct count of projects" {
            $proj1 = New-Object SfProject -Property @{
                branch        = "test-branch";
                id            = "id1";
            }

            _sfData-save-project -context $proj1
            [SfProject[]]$projects = sf-get-allProjects
            $projects | Should -HaveCount 1
            $projects[0].id | Should -Be "id1"
            $projects[0].branch | Should -Be "test-branch"
        }

        It "return correct count of projects when many" {
            $proj1 = New-Object SfProject -Property @{
                branch        = "test-branch";
                id            = "id1";
            }

            _sfData-save-project -context $proj1
            $proj1.id = 'id2'
            _sfData-save-project -context $proj1

            [SfProject[]]$projects = sf-get-allProjects
            $projects | Should -HaveCount 2
            $projects[0].id | Should -Be "id1"
            $projects[1].id | Should -Be "id2"
            $projects[0].branch | Should -Be "test-branch"
        }
    }
}