. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "`$Global:sf should" -Tags ("fluent") {
        Mock _validate-project { }
        Mock _initialize-project { }
        Mock _sfData-get-allProjects { [SfProject]::new([Guid]::NewGuid()) }
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

    Describe "`$Tags fluent" -Tags ("fluent") {
        Mock _initialize-project { }
        Mock _validate-project { }
        Mock set-consoleTitle { }
        $testTag1 = 'test-tag-1'
        $testTag2 = 'test-tag-2'
        $testTag3 = 'test-tag-3'
        $testTag4 = 'test-tag-4'
        set-currentProject -newContext [SfProject]::new([Guid]::NewGuid())

        It "Add single tag to project" {
            $sf.project.tags.Add($testTag1)
            [SfProject]$proj = (_sfData-get-allProjects)[0]
            $proj.tags | Should -Be $testTag1
            set-currentProject $proj
            $sf.project.tags.GetAll() | Should -Be $testTag1
        }
        It "Add multiple tags to project" {
            $expectedTags = "$testTag1 $testTag2 $testTag3"
            $sf.project.tags.Add($testTag2)
            $sf.project.tags.Add($testTag3)
            [SfProject]$proj = (_sfData-get-allProjects)[0]
            $proj.tags | Should -Be $expectedTags
            set-currentProject $proj
            $sf.project.tags.GetAll() | Should -Be $expectedTags
        }
        It "Remove tag from project" {
            $expectedTags = "$testTag1 $testTag3"

            [SfProject]$proj = (_sfData-get-allProjects)[0]
            set-currentProject $proj
            $sf.project.tags.Remove($testTag2)
            
            [SfProject]$proj = (_sfData-get-allProjects)[0]
            set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            $sf.project.tags.GetAll() | Should -Be $expectedTags
        }
        It "Remove multiple tags from project" {
            $expectedTags = "$testTag1 $testTag4"
            $sf.project.tags.Add($testTag2)
            $sf.project.tags.Add($testTag4)

            [SfProject]$proj = (_sfData-get-allProjects)[0]
            set-currentProject $proj
            $sf.project.tags.Remove($testTag2)
            $sf.project.tags.Remove($testTag3)
            
            [SfProject]$proj = (_sfData-get-allProjects)[0]
            set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            $sf.project.tags.GetAll() | Should -Be $expectedTags
        }
        It "Remove first tag" {
            $expectedTags = "$testTag4"

            [SfProject]$proj = (_sfData-get-allProjects)[0]
            set-currentProject $proj
            $sf.project.tags.Remove($testTag1)
            
            [SfProject]$proj = (_sfData-get-allProjects)[0]
            set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            $sf.project.tags.GetAll() | Should -Be $expectedTags
        }
        It "Remove last tag" {
            $expectedTags = "$testTag4"
            $sf.project.tags.Add($testTag2)

            [SfProject]$proj = (_sfData-get-allProjects)[0]
            set-currentProject $proj
            $sf.project.tags.Remove($testTag2)
            
            [SfProject]$proj = (_sfData-get-allProjects)[0]
            set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            $sf.project.tags.GetAll() | Should -Be $expectedTags
        }
        It "Not accept tags starting with '-'" {
            { $sf.project.tags.Add("-dffd") } | Should -Throw -ExpectedMessage "Invalid tag name."
        }
        It "Not accept tags with spaces" {
            { $sf.project.tags.Add("df fd") } | Should -Throw -ExpectedMessage "Invalid tag name."
        }
        It "Not accept Null or empty tags" {
            { $sf.project.tags.Add("") } | Should -Throw -ExpectedMessage "Invalid tag name."
            { $sf.project.tags.Add(" ") } | Should -Throw -ExpectedMessage "Invalid tag name."
            { $sf.project.tags.Add($null) } | Should -Throw -ExpectedMessage "Invalid tag name."
        }

        sf-delete-project -context $testProj -noPrompt
    }
}