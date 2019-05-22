. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

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
            [SfProject]$proj = (get-allProjectsForCurrentContainer)[0]
            $proj.tags | Should -Be $testTag1
            set-currentProject $proj
            $sf.project.tags.GetAll() | Should -Be $testTag1
        }
        It "Add multiple tags to project" {
            $expectedTags = "$testTag1 $testTag2 $testTag3"
            $sf.project.tags.Add($testTag2)
            $sf.project.tags.Add($testTag3)
            [SfProject]$proj = (get-allProjectsForCurrentContainer)[0]
            $proj.tags | Should -Be $expectedTags
            set-currentProject $proj
            $sf.project.tags.GetAll() | Should -Be $expectedTags
        }
        It "Remove tag from project" {
            $expectedTags = "$testTag1 $testTag3"

            [SfProject]$proj = (get-allProjectsForCurrentContainer)[0]
            set-currentProject $proj
            $sf.project.tags.Remove($testTag2)
            
            [SfProject]$proj = (get-allProjectsForCurrentContainer)[0]
            set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            $sf.project.tags.GetAll() | Should -Be $expectedTags
        }
        It "Remove multiple tags from project" {
            $expectedTags = "$testTag1 $testTag4"
            $sf.project.tags.Add($testTag2)
            $sf.project.tags.Add($testTag4)

            [SfProject]$proj = (get-allProjectsForCurrentContainer)[0]
            set-currentProject $proj
            $sf.project.tags.Remove($testTag2)
            $sf.project.tags.Remove($testTag3)
            
            [SfProject]$proj = (get-allProjectsForCurrentContainer)[0]
            set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            $sf.project.tags.GetAll() | Should -Be $expectedTags
        }
        It "Remove first tag" {
            $expectedTags = "$testTag4"

            [SfProject]$proj = (get-allProjectsForCurrentContainer)[0]
            set-currentProject $proj
            $sf.project.tags.Remove($testTag1)
            
            [SfProject]$proj = (get-allProjectsForCurrentContainer)[0]
            set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            $sf.project.tags.GetAll() | Should -Be $expectedTags
        }
        It "Remove last tag" {
            $expectedTags = "$testTag4"
            $sf.project.tags.Add($testTag2)

            [SfProject]$proj = (get-allProjectsForCurrentContainer)[0]
            set-currentProject $proj
            $sf.project.tags.Remove($testTag2)
            
            [SfProject]$proj = (get-allProjectsForCurrentContainer)[0]
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