. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "Tags should" -Tags ("fluent") {
        Mock _initializeProject { }
        Mock _validateProject { }
        Mock _setConsoleTitle { }
        $testTag1 = 'test-tag-1'
        $testTag2 = 'test-tag-2'
        $testTag3 = 'test-tag-3'
        $testTag4 = 'test-tag-4'
        proj_setCurrent -newContext $([SfProject]::new())

        It "Add single tag to project" {
            proj_tags_add -tagName $testTag1
            [SfProject]$proj = (data_getAllProjects)[0]
            $proj.tags | Should -Be $testTag1
            proj_setCurrent $proj
            proj_tags_getAll | Should -Be $testTag1
        }
        It "Add multiple tags to project" {
            $expectedTags = "$testTag1 $testTag2 $testTag3"
            proj_tags_add $testTag2
            proj_tags_add $testTag3
            [SfProject]$proj = (data_getAllProjects)[0]
            $proj.tags | Should -Be $expectedTags
            proj_setCurrent $proj
            proj_tags_getAll | Should -Be $expectedTags
        }
        It "Remove tag from project" {
            $expectedTags = "$testTag1 $testTag3"

            [SfProject]$proj = (data_getAllProjects)[0]
            proj_setCurrent $proj
            proj_tags_remove $testTag2
            
            [SfProject]$proj = (data_getAllProjects)[0]
            proj_setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            proj_tags_getAll | Should -Be $expectedTags
        }
        It "Remove multiple tags from project" {
            $expectedTags = "$testTag1 $testTag4"
            proj_tags_add $testTag2
            proj_tags_add $testTag4

            [SfProject]$proj = (data_getAllProjects)[0]
            proj_setCurrent $proj
            proj_tags_remove $testTag2
            proj_tags_remove $testTag3
            
            [SfProject]$proj = (data_getAllProjects)[0]
            proj_setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            proj_tags_getAll | Should -Be $expectedTags
        }
        It "Remove first tag" {
            $expectedTags = "$testTag4"

            [SfProject]$proj = (data_getAllProjects)[0]
            proj_setCurrent $proj
            proj_tags_remove $testTag1
            
            [SfProject]$proj = (data_getAllProjects)[0]
            proj_setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            proj_tags_getAll | Should -Be $expectedTags
        }
        It "Remove last tag" {
            $expectedTags = "$testTag4"
            proj_tags_add $testTag2

            [SfProject]$proj = (data_getAllProjects)[0]
            proj_setCurrent $proj
            proj_tags_remove $testTag2
            
            [SfProject]$proj = (data_getAllProjects)[0]
            proj_setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            proj_tags_getAll | Should -Be $expectedTags
        }
        It "Not accept tags starting with '-'" {
            { proj_tags_add "-ffd" } | Should -Throw -ExpectedMessage "Invalid tag name."
        }
        It "Not accept tags with spaces" {
            { proj_tags_add "dffd dfds" } | Should -Throw -ExpectedMessage "Invalid tag name."
        }
        It "Not accept Null or empty tags" {
            { proj_tags_add "   "} | Should -Throw -ExpectedMessage "Invalid tag name."
            { proj_tags_add "" } | Should -Throw -ExpectedMessage "Invalid tag name."
            { proj_tags_add $null } | Should -Throw -ExpectedMessage "Invalid tag name."
        }

        proj_remove -context $testProj -noPrompt
    }
}
