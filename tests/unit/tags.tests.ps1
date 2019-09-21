. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "Tags should" -Tags ("fluent") {
        Mock _initialize-project { }
        Mock _validate-project { }
        Mock set-consoleTitle { }
        $testTag1 = 'test-tag-1'
        $testTag2 = 'test-tag-2'
        $testTag3 = 'test-tag-3'
        $testTag4 = 'test-tag-4'
        set-currentProject -newContext $([SfProject]::new())

        It "Add single tag to project" {
            sf-add-tagToProject -tagName $testTag1
            [SfProject]$proj = (sf-get-allProjects)[0]
            $proj.tags | Should -Be $testTag1
            set-currentProject $proj
            sf-get-allTagsForProject | Should -Be $testTag1
        }
        It "Add multiple tags to project" {
            $expectedTags = "$testTag1 $testTag2 $testTag3"
            sf-add-tagToProject $testTag2
            sf-add-tagToProject $testTag3
            [SfProject]$proj = (sf-get-allProjects)[0]
            $proj.tags | Should -Be $expectedTags
            set-currentProject $proj
            sf-get-allTagsForProject | Should -Be $expectedTags
        }
        It "Remove tag from project" {
            $expectedTags = "$testTag1 $testTag3"

            [SfProject]$proj = (sf-get-allProjects)[0]
            set-currentProject $proj
            sf-remove-tagFromProject $testTag2
            
            [SfProject]$proj = (sf-get-allProjects)[0]
            set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            sf-get-allTagsForProject | Should -Be $expectedTags
        }
        It "Remove multiple tags from project" {
            $expectedTags = "$testTag1 $testTag4"
            sf-add-tagToProject $testTag2
            sf-add-tagToProject $testTag4

            [SfProject]$proj = (sf-get-allProjects)[0]
            set-currentProject $proj
            sf-remove-tagFromProject $testTag2
            sf-remove-tagFromProject $testTag3
            
            [SfProject]$proj = (sf-get-allProjects)[0]
            set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            sf-get-allTagsForProject | Should -Be $expectedTags
        }
        It "Remove first tag" {
            $expectedTags = "$testTag4"

            [SfProject]$proj = (sf-get-allProjects)[0]
            set-currentProject $proj
            sf-remove-tagFromProject $testTag1
            
            [SfProject]$proj = (sf-get-allProjects)[0]
            set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            sf-get-allTagsForProject | Should -Be $expectedTags
        }
        It "Remove last tag" {
            $expectedTags = "$testTag4"
            sf-add-tagToProject $testTag2

            [SfProject]$proj = (sf-get-allProjects)[0]
            set-currentProject $proj
            sf-remove-tagFromProject $testTag2
            
            [SfProject]$proj = (sf-get-allProjects)[0]
            set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            sf-get-allTagsForProject | Should -Be $expectedTags
        }
        It "Not accept tags starting with '-'" {
            { sf-add-tagToProject "-ffd" } | Should -Throw -ExpectedMessage "Invalid tag name."
        }
        It "Not accept tags with spaces" {
            { sf-add-tagToProject "dffd dfds" } | Should -Throw -ExpectedMessage "Invalid tag name."
        }
        It "Not accept Null or empty tags" {
            { sf-add-tagToProject "   "} | Should -Throw -ExpectedMessage "Invalid tag name."
            { sf-add-tagToProject "" } | Should -Throw -ExpectedMessage "Invalid tag name."
            { sf-add-tagToProject $null } | Should -Throw -ExpectedMessage "Invalid tag name."
        }

        sf-delete-project -context $testProj -noPrompt
    }
}