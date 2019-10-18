. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "Tags should" -Tags ("fluent") {
        Mock _sf-proj-refreshData { }
        Mock _validateProject { }
        Mock _setConsoleTitle { }
        $testTag1 = 'test-tag-1'
        $testTag2 = 'test-tag-2'
        $testTag3 = 'test-tag-3'
        $testTag4 = 'test-tag-4'
        sf-proj-setCurrent -newContext $([SfProject]::new())

        It "Add single tag to project" {
            sf-proj-tags-addToCurrent -tagName $testTag1
            [SfProject]$proj = (sf-data-getAllProjects)[0]
            $proj.tags | Should -Be $testTag1
            sf-proj-setCurrent $proj
            sf-proj-tags-getAllFromCurrent | Should -Be $testTag1
        }
        It "Add multiple tags to project" {
            $expectedTags = "$testTag1 $testTag2 $testTag3"
            sf-proj-tags-addToCurrent $testTag2
            sf-proj-tags-addToCurrent $testTag3
            [SfProject]$proj = (sf-data-getAllProjects)[0]
            $proj.tags | Should -Be $expectedTags
            sf-proj-setCurrent $proj
            sf-proj-tags-getAllFromCurrent | Should -Be $expectedTags
        }
        It "Remove tag from project" {
            $expectedTags = "$testTag1 $testTag3"

            [SfProject]$proj = (sf-data-getAllProjects)[0]
            sf-proj-setCurrent $proj
            sf-proj-tags-removeFromCurrent $testTag2
            
            [SfProject]$proj = (sf-data-getAllProjects)[0]
            sf-proj-setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            sf-proj-tags-getAllFromCurrent | Should -Be $expectedTags
        }
        It "Remove multiple tags from project" {
            $expectedTags = "$testTag1 $testTag4"
            sf-proj-tags-addToCurrent $testTag2
            sf-proj-tags-addToCurrent $testTag4

            [SfProject]$proj = (sf-data-getAllProjects)[0]
            sf-proj-setCurrent $proj
            sf-proj-tags-removeFromCurrent $testTag2
            sf-proj-tags-removeFromCurrent $testTag3
            
            [SfProject]$proj = (sf-data-getAllProjects)[0]
            sf-proj-setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            sf-proj-tags-getAllFromCurrent | Should -Be $expectedTags
        }
        It "Remove first tag" {
            $expectedTags = "$testTag4"

            [SfProject]$proj = (sf-data-getAllProjects)[0]
            sf-proj-setCurrent $proj
            sf-proj-tags-removeFromCurrent $testTag1
            
            [SfProject]$proj = (sf-data-getAllProjects)[0]
            sf-proj-setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            sf-proj-tags-getAllFromCurrent | Should -Be $expectedTags
        }
        It "Remove last tag" {
            $expectedTags = "$testTag4"
            sf-proj-tags-addToCurrent $testTag2

            [SfProject]$proj = (sf-data-getAllProjects)[0]
            sf-proj-setCurrent $proj
            sf-proj-tags-removeFromCurrent $testTag2
            
            [SfProject]$proj = (sf-data-getAllProjects)[0]
            sf-proj-setCurrent $proj
            $proj.tags | Should -Be $expectedTags
            sf-proj-tags-getAllFromCurrent | Should -Be $expectedTags
        }
        It "Not accept tags starting with '-'" {
            { sf-proj-tags-addToCurrent "-ffd" } | Should -Throw -ExpectedMessage "Invalid tag name."
        }
        It "Not accept tags with spaces" {
            { sf-proj-tags-addToCurrent "dffd dfds" } | Should -Throw -ExpectedMessage "Invalid tag name."
        }
        It "Not accept Null or empty tags" {
            { sf-proj-tags-addToCurrent "   "} | Should -Throw -ExpectedMessage "Invalid tag name."
            { sf-proj-tags-addToCurrent "" } | Should -Throw -ExpectedMessage "Invalid tag name."
            { sf-proj-tags-addToCurrent $null } | Should -Throw -ExpectedMessage "Invalid tag name."
        }

        sf-proj-remove -context $testProj -noPrompt
    }

    Describe "_sf-proj-tags-setNewProjectDefaultTags should" {
        $Script:filter = $null
        Mock sf-proj-tags-getDefaultFilter {
            $Script:filter
        }
        
        $test = {
            [SfProject]$p = _newSfProjectObject -id 'testId'
            _sf-proj-tags-setNewProjectDefaultTags -project $p
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
