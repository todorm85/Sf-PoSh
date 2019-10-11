. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "sf-data-getAllProjects" {
        Mock _sf-proj-refreshData { }

        It "return empty collection when no projects" {
            $projects = sf-data-getAllProjects
            $projects | Should -HaveCount 0
        }

        It "return correct count of projects" {
            $proj1 = New-Object SfProject -Property @{
                branch        = "test-branch";
                id            = "id1";
            }

            _setProjectData -context $proj1
            [SfProject[]]$projects = sf-data-getAllProjects
            $projects | Should -HaveCount 1
            $projects[0].id | Should -Be "id1"
            $projects[0].branch | Should -Be "test-branch"
        }

        It "return correct count of projects when many" {
            $proj1 = New-Object SfProject -Property @{
                branch        = "test-branch";
                id            = "id1";
            }

            _setProjectData -context $proj1
            $proj1.id = 'id2'
            _setProjectData -context $proj1

            [SfProject[]]$projects = sf-data-getAllProjects
            $projects | Should -HaveCount 2
            $projects[0].id | Should -Be "id1"
            $projects[1].id | Should -Be "id2"
            $projects[0].branch | Should -Be "test-branch"
        }
    }
}
