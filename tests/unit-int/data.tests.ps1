. "${PSScriptRoot}\load.ps1"

InModuleScope sf-dev {
    . "${PSScriptRoot}\init.ps1"

    Describe "sd-project-getAll" {
        Mock _proj-initialize { }

        It "return empty collection when no projects" {
            $projects = sd-project-getAll
            $projects | Should -HaveCount 0
        }

        It "return correct count of projects" {
            $proj1 = New-Object SfProject -Property @{
                id = "id1";
            }

            _setProjectData -context $proj1
            [SfProject[]]$projects = sd-project-getAll
            $projects | Should -HaveCount 1
            $projects[0].id | Should -Be "id1"
        }

        It "return correct count of projects when many" {
            $proj1 = New-Object SfProject -Property @{
                id = "id1";
            }

            _setProjectData -context $proj1
            $proj1.id = 'id2'
            _setProjectData -context $proj1

            [SfProject[]]$projects = sd-project-getAll
            $projects | Should -HaveCount 2
            $projects[0].id | Should -Be "id1"
            $projects[1].id | Should -Be "id2"
        }

        It "persists defaultBinding correctly" {
            sd-project-getAll | % { sd-project-remove $_ -noPrompt }
            $proj1 = New-Object SfProject -Property @{
                id             = "idsb";
                defaultBinding = [SiteBinding]@{
                    domain   = "test";
                    port     = "55";
                    protocol = "https"
                }
            }

            _setProjectData -context $proj1

            [SfProject[]]$projects = sd-project-getAll
            $projects | Should -HaveCount 1
            $projects[0].defaultBinding.domain | Should -Be "test"
            $projects[0].defaultBinding.port | Should -Be "55"
            $projects[0].defaultBinding.protocol | Should -Be "https"
        }
    }
}
