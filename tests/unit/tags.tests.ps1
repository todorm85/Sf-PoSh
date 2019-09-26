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
        proj-setCurrent -newContext $([SfProject]::new())

        It "Add single tag to project" {
            proj-tags-add -tagName $testTag1
            [SfProject]$proj = (data-getAllProjects)[0]
            $proj.tags | Should -Be $testTag1
            proj-setCurrent $proj
            proj-tags-getAll | Should -Be $testTag1
        }
        It "Add multiple tags to project" {
            $expectedTags = "$testTag1 $testTag2 $testTag3"
            proj-tags-add $testTag2
            proj-tags-add $testTag3
            [SfProject]$proj = (data-getAllProjects)[0]
            $proj.tags | Should -Be $expectedTags
            proj-setCurrent $proj
            proj-tags-getAll | Should -Be $expectedTags
        }
        It "Remove tag from project" {
            $expectedTags = "$testTag1 $testTag3"

            [SfProject]$proj = (data-getAllProjects)[0]
            proj-setCurrent $proj
            proj-tags-remove $testTag2
            
            [SfProject]$proj = (data-getAllProjects)[0]
            proj-setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            proj-tags-getAll | Should -Be $expectedTags
        }
        It "Remove multiple tags from project" {
            $expectedTags = "$testTag1 $testTag4"
            proj-tags-add $testTag2
            proj-tags-add $testTag4

            [SfProject]$proj = (data-getAllProjects)[0]
            proj-setCurrent $proj
            proj-tags-remove $testTag2
            proj-tags-remove $testTag3
            
            [SfProject]$proj = (data-getAllProjects)[0]
            proj-setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            proj-tags-getAll | Should -Be $expectedTags
        }
        It "Remove first tag" {
            $expectedTags = "$testTag4"

            [SfProject]$proj = (data-getAllProjects)[0]
            proj-setCurrent $proj
            proj-tags-remove $testTag1
            
            [SfProject]$proj = (data-getAllProjects)[0]
            proj-setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            proj-tags-getAll | Should -Be $expectedTags
        }
        It "Remove last tag" {
            $expectedTags = "$testTag4"
            proj-tags-add $testTag2

            [SfProject]$proj = (data-getAllProjects)[0]
            proj-setCurrent $proj
            proj-tags-remove $testTag2
            
            [SfProject]$proj = (data-getAllProjects)[0]
            proj-setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            proj-tags-getAll | Should -Be $expectedTags
        }
        It "Not accept tags starting with '-'" {
            { proj-tags-add "-ffd" } | Should -Throw -ExpectedMessage "Invalid tag name."
        }
        It "Not accept tags with spaces" {
            { proj-tags-add "dffd dfds" } | Should -Throw -ExpectedMessage "Invalid tag name."
        }
        It "Not accept Null or empty tags" {
            { proj-tags-add "   "} | Should -Throw -ExpectedMessage "Invalid tag name."
            { proj-tags-add "" } | Should -Throw -ExpectedMessage "Invalid tag name."
            { proj-tags-add $null } | Should -Throw -ExpectedMessage "Invalid tag name."
        }

        proj-remove -context $testProj -noPrompt
    }
}
