. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "`$Global:sf should" -Tags ("fluent") {
        Mock _validate-project { }
        Mock _initialize-project { }
        Mock Set-Location { }

        It "initialize with empty project after module load" {
            { $Global:sf.GetProject() } | Should -Throw -ExpectedMessage "You must select a project to work with first."
        }
        It "initialize when selecting project from global scope function" {
            $testId = "testId1";
            Mock prompt-projectSelect {
                [SfProject]@{
                    id = $testId
                }
            }

            sf-select-project
            $Global:sf.GetProject().id | Should -Be $testId
        }
        It "initialize global scope when selecting project from fluent" {
            $testId = "testId2";
            $Global:sf.GetProject().id | Should -Not -Be $testId
            (_get-selectedProject).id | Should -Not -Be $testId
            Mock prompt-projectSelect {
                [SfProject]@{
                    id = $testId
                }
            }
            
            $Global:sf.project.Select()
            $Global:sf.GetProject().id | Should -Be $testId
            (_get-selectedProject).id | Should -Be $testId
        }
    }

    Describe "MasterFluent should" {
        Mock _validate-project { }
        Mock _initialize-project { }
        Mock Set-Location { }
        
        Context "initialize child facades" {
            It "Intiialize facades even if empty project" {
                $facade = [MasterFluent]::new($null)
                $facade.solution | Should -Not -BeNullOrEmpty
                $facade.webApp | Should -Not -BeNullOrEmpty
                $facade.IIS | Should -Not -BeNullOrEmpty
                $facade.project | Should -Not -BeNullOrEmpty
            }
            It "Intiialize facades" {
                $facade = [MasterFluent]::new([SfProject]@{ id = "testId3" })
                $facade.solution | Should -Not -BeNullOrEmpty
                $facade.webApp | Should -Not -BeNullOrEmpty
                $facade.IIS | Should -Not -BeNullOrEmpty
                $facade.project | Should -Not -BeNullOrEmpty
            }
        }
    }

    Describe "Project fluent should" {
        Mock _validate-project { }
        Mock _initialize-project { }
        Mock Set-Location { }

        Context "warn no project selected when" {
            $facade = [ProjectFluent]::new($null)

            It "Clone" {
                { $facade.Clone() } | Should -Throw -ExpectedMessage "You must select a project to work with first."
            }
            It "Delete" {
                { $facade.Delete() } | Should -Throw -ExpectedMessage "You must select a project to work with first."
            }
            It "Rename" {
                { $facade.Rename('test') } | Should -Throw -ExpectedMessage "You must select a project to work with first."
            }
        }
    }
}