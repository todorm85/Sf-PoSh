. "${PSScriptRoot}\Infrastructure\load-module.ps1"

InModuleScope sf-dev {
    Describe "`$Global:sf should" -Tags ("fluent") {
        It "initialize with empty project after module load" {
            $sf.project | Should -BeNullOrEmpty
        }
        It "initialize when selecting project from global scope function" {
            $testId = "testId1";
            $sf.project.id | Should -Not -Be $testId

            Mock prompt-projectSelect {
                [SfProject]@{
                    id = $testId
                }
            }

            Mock _validate-project { }
            Mock Set-Location { }

            sf-select-project
            $sf.project.id | Should -Be $testId
        }
        It "initialize global scope when selecting project from fluent" {
            $testId = "testId2";
            $sf.project.id | Should -Not -Be $testId
            (_get-selectedProject).id | Should -Not -Be $testId
            Mock prompt-projectSelect {
                [SfProject]@{
                    id = $testId
                }
            }

            Mock _validate-project { }
            Mock Set-Location { }
            
            $sf.Select()
            $sf.project.id | Should -Be $testId
            (_get-selectedProject).id | Should -Be $testId
        }
    }

    Describe "ProjectFluent should" {
        $facade = [ProjectFluent]::new()
        It "Intiialize solution facade even if empty project" {
            $facade.solution | Should -Not -BeNullOrEmpty
        }

        Context "warn no project selected when" {
            It "clone" {
                { $facade.Clone() } | Should -Throw -ExpectedMessage "You must select a project to work with first."
            }
            It "Delete" {
                { $facade.Delete() } | Should -Throw -ExpectedMessage "You must select a project to work with first."
            }
            It "Rename" {
                { $facade.Rename('test') } | Should -Throw -ExpectedMessage "You must select a project to work with first."
            }
            It "Build" {
                { $facade.Build() } | Should -Throw -ExpectedMessage "You must select a project to work with first."
            }
            It "OpenSolution" {
                { $facade.OpenSolution() } | Should -Throw -ExpectedMessage "You must select a project to work with first."
            }
            It "OpenWebsite" {
                { $facade.OpenWebsite() } | Should -Throw -ExpectedMessage "You must select a project to work with first."
            }
            It "ResetWebApp" {
                { $facade.ResetWebApp() } | Should -Throw -ExpectedMessage "You must select a project to work with first."
            }
            It "ResetAppPool" {
                { $facade.ResetAppPool() } | Should -Throw -ExpectedMessage "You must select a project to work with first."
            }
        }
    }
}