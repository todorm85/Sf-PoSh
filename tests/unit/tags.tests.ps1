. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "Tags should" -Tags ("fluent") {
        Mock _proj-refreshData { }
        Mock _validateProject { }
        Mock _setConsoleTitle { }
        $testTag1 = 'test-tag-1'
        $testTag2 = 'test-tag-2'
        $testTag3 = 'test-tag-3'
        $testTag4 = 'test-tag-4'
        $result = proj-setCurrent -newContext $([SfProject]::new())

        It "Add single tag to project" {
            tag-addToCurrent -tagName $testTag1
            [SfProject]$proj = (_data-getAllProjects)[0]
            $proj.tags | Should -Be $testTag1
            $result = proj-setCurrent $proj
            tag-getAllFromCurrent | Should -Be $testTag1
        }
        It "Add multiple tags to project" {
            $expectedTags = "$testTag1 $testTag2 $testTag3"
            tag-addToCurrent $testTag2
            tag-addToCurrent $testTag3
            [SfProject]$proj = (_data-getAllProjects)[0]
            $proj.tags | Should -Be $expectedTags
            $result = proj-setCurrent $proj
            tag-getAllFromCurrent | Should -Be $expectedTags
        }
        It "Remove tag from project" {
            $expectedTags = "$testTag1 $testTag3"

            [SfProject]$proj = (_data-getAllProjects)[0]
            $result = proj-setCurrent $proj
            tag-removeFromCurrent $testTag2
            
            [SfProject]$proj = (_data-getAllProjects)[0]
            $result = proj-setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            tag-getAllFromCurrent | Should -Be $expectedTags
        }
        It "Remove multiple tags from project" {
            $expectedTags = "$testTag1 $testTag4"
            tag-addToCurrent $testTag2
            tag-addToCurrent $testTag4

            [SfProject]$proj = (_data-getAllProjects)[0]
            $result = proj-setCurrent $proj
            tag-removeFromCurrent $testTag2
            tag-removeFromCurrent $testTag3
            
            [SfProject]$proj = (_data-getAllProjects)[0]
            $result = proj-setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            tag-getAllFromCurrent | Should -Be $expectedTags
        }
        It "Remove first tag" {
            $expectedTags = "$testTag4"

            [SfProject]$proj = (_data-getAllProjects)[0]
            $result = proj-setCurrent $proj
            tag-removeFromCurrent $testTag1
            
            [SfProject]$proj = (_data-getAllProjects)[0]
            $result = proj-setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            tag-getAllFromCurrent | Should -Be $expectedTags
        }
        It "Remove last tag" {
            $expectedTags = "$testTag4"
            tag-addToCurrent $testTag2

            [SfProject]$proj = (_data-getAllProjects)[0]
            $result = proj-setCurrent $proj
            tag-removeFromCurrent $testTag2
            
            [SfProject]$proj = (_data-getAllProjects)[0]
            $result = proj-setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            tag-getAllFromCurrent | Should -Be $expectedTags
        }
        It "Not accept tags starting with '-'" {
            { tag-addToCurrent "-ffd" } | Should -Throw -ExpectedMessage "Invalid tag name."
        }
        It "Not accept tags with spaces" {
            { tag-addToCurrent "dffd dfds" } | Should -Throw -ExpectedMessage "Invalid tag name."
        }
        It "Not accept Null or empty tags" {
            { tag-addToCurrent "   "} | Should -Throw -ExpectedMessage "Invalid tag name."
            { tag-addToCurrent "" } | Should -Throw -ExpectedMessage "Invalid tag name."
            { tag-addToCurrent $null } | Should -Throw -ExpectedMessage "Invalid tag name."
        }

        proj-remove -context $testProj -noPrompt
    }

    Describe "_tag-setNewProjectDefaultTags should" {
        $Script:filter = $null
        Mock tag-getDefaultFilter {
            $Script:filter
        }
        
        $test = {
            [SfProject]$p = _newSfProjectObject -id 'testId'
            _tag-setNewProjectDefaultTags -project $p
            $p.tags
        }

        It "set none tags when default tags filter has not been set" {
            $result = Invoke-Command -ScriptBlock $test
            $result | Should -BeNullOrEmpty
        }
        It "set none tags when default tags filter is empty" {
            $Script:filter = ""
            $result = Invoke-Command -ScriptBlock $test
            $result | Should -BeNullOrEmpty
        }
        It "set none tags when default tags filter has only exclude tags" {
            $Script:filter = '-e1 -e2'
            $result = Invoke-Command -ScriptBlock $test
            $result | Should -BeNullOrEmpty
        }
        It "set none tags when default tags filter has one exclude tags" {
            $Script:filter = '-e1'
            $result = Invoke-Command -ScriptBlock $test
            $result | Should -BeNullOrEmpty
        }
        It "set only include tags when default tags filter has both include and exclude tags" {
            $Script:filter = '-e1 i1 -e3 i2'
            $result = Invoke-Command -ScriptBlock $test
            $result.Split(' ') | Should -Contain 'i1'
            $result.Split(' ') | Should -Contain 'i2'
            $result.Split(' ') | Should -Not -Contain 'e1'
            $result.Split(' ') | Should -Not -Contain 'e3'
        }
        It "set only include tags when default tags filter has one include tag" {
            $Script:filter = 'i1'
            $result = Invoke-Command -ScriptBlock $test
            $result.Split(' ') | Should -Contain 'i1'
        }
        It "set only include tags when default tags filter has only include tags" {
            $Script:filter = 'i1 i2 i3'
            $result = Invoke-Command -ScriptBlock $test
            $result.Split(' ') | Should -Contain 'i1'
            $result.Split(' ') | Should -Contain 'i2'
            $result.Split(' ') | Should -Contain 'i3'
        }
    }
}
