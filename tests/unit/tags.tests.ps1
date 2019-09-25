. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "Tags should" -Tags ("fluent") {
        Mock _initialize-project { }
        Mock _validate-project { }
        Mock _set-consoleTitle { }
        $testTag1 = 'test-tag-1'
        $testTag2 = 'test-tag-2'
        $testTag3 = 'test-tag-3'
        $testTag4 = 'test-tag-4'
        _set-currentProject -newContext $([SfProject]::new())

        It "Add single tag to project" {
            add-tagToProject -tagName $testTag1
            [SfProject]$proj = (get-allProjects)[0]
            $proj.tags | Should -Be $testTag1
            _set-currentProject $proj
            get-allTagsForProject | Should -Be $testTag1
        }
        It "Add multiple tags to project" {
            $expectedTags = "$testTag1 $testTag2 $testTag3"
            add-tagToProject $testTag2
            add-tagToProject $testTag3
            [SfProject]$proj = (get-allProjects)[0]
            $proj.tags | Should -Be $expectedTags
            _set-currentProject $proj
            get-allTagsForProject | Should -Be $expectedTags
        }
        It "Remove tag from project" {
            $expectedTags = "$testTag1 $testTag3"

            [SfProject]$proj = (get-allProjects)[0]
            _set-currentProject $proj
            remove-tagFromProject $testTag2
            
            [SfProject]$proj = (get-allProjects)[0]
            _set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            get-allTagsForProject | Should -Be $expectedTags
        }
        It "Remove multiple tags from project" {
            $expectedTags = "$testTag1 $testTag4"
            add-tagToProject $testTag2
            add-tagToProject $testTag4

            [SfProject]$proj = (get-allProjects)[0]
            _set-currentProject $proj
            remove-tagFromProject $testTag2
            remove-tagFromProject $testTag3
            
            [SfProject]$proj = (get-allProjects)[0]
            _set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            get-allTagsForProject | Should -Be $expectedTags
        }
        It "Remove first tag" {
            $expectedTags = "$testTag4"

            [SfProject]$proj = (get-allProjects)[0]
            _set-currentProject $proj
            remove-tagFromProject $testTag1
            
            [SfProject]$proj = (get-allProjects)[0]
            _set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            get-allTagsForProject | Should -Be $expectedTags
        }
        It "Remove last tag" {
            $expectedTags = "$testTag4"
            add-tagToProject $testTag2

            [SfProject]$proj = (get-allProjects)[0]
            _set-currentProject $proj
            remove-tagFromProject $testTag2
            
            [SfProject]$proj = (get-allProjects)[0]
            _set-currentProject $proj
            $proj.tags | Should -Be $expectedTags
            get-allTagsForProject | Should -Be $expectedTags
        }
        It "Not accept tags starting with '-'" {
            { add-tagToProject "-ffd" } | Should -Throw -ExpectedMessage "Invalid tag name."
        }
        It "Not accept tags with spaces" {
            { add-tagToProject "dffd dfds" } | Should -Throw -ExpectedMessage "Invalid tag name."
        }
        It "Not accept Null or empty tags" {
            { add-tagToProject "   "} | Should -Throw -ExpectedMessage "Invalid tag name."
            { add-tagToProject "" } | Should -Throw -ExpectedMessage "Invalid tag name."
            { add-tagToProject $null } | Should -Throw -ExpectedMessage "Invalid tag name."
        }

        Remove-Project -context $testProj -noPrompt
    }
}