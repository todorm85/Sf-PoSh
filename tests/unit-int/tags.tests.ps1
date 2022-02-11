. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {
    
    Describe "Tags should" -Tags ("fluent") {
        InTestProjectScope {

            $testTag1 = 'test-sd-projectTags-1'
            $testTag2 = 'test-sd-projectTags-2'
            $testTag3 = 'test-sd-projectTags-3'
            $testTag4 = 'test-sd-projectTags-4'

            It "Add single tag to project" {
                sf-project-tags-add -tagName $testTag1
                [SfProject]$proj = (sf-project-get -all)[0]
                $proj.tags | Should -Contain $testTag1
                $result = sf-project-setCurrent $proj
                sf-project-tags-get | Should -Contain $testTag1
                sf-project-tags-get | Should -HaveCount 1
            }
            It "Add multiple tags to project" {
                $expectedTags = @($testTag1, $testTag2, $testTag3)
                sf-project-tags-add -tagName $testTag2
                sf-project-tags-add -tagName $testTag3
                [SfProject]$proj = (sf-project-get -all)[0]
                $proj.tags | Should -Be $expectedTags
                $result = sf-project-setCurrent $proj
                sf-project-tags-get | Should -Be $expectedTags
            }
            It "Remove tag from project" {
                $expectedTags = @($testTag1, $testTag3)

                [SfProject]$proj = (sf-project-get -all)[0]
                $result = sf-project-setCurrent $proj
                sf-project-tags-remove -tagName $testTag2

                [SfProject]$proj = (sf-project-get -all)[0]
                $result = sf-project-setCurrent $proj
                $proj.tags | Should -Be $expectedTags
                sf-project-tags-get | Should -Be $expectedTags
            }
            It "Remove multiple tags from project" {
                $expectedTags = @($testTag1, $testTag4)
                sf-project-tags-add -tagName $testTag2
                sf-project-tags-add -tagName $testTag4

                [SfProject]$proj = (sf-project-get -all)[0]
                $result = sf-project-setCurrent $proj
                sf-project-tags-remove -tagName $testTag2
                sf-project-tags-remove -tagName $testTag3

                [SfProject]$proj = (sf-project-get -all)[0]
                $result = sf-project-setCurrent $proj
                $proj.tags | Should -Be $expectedTags
                sf-project-tags-get | Should -Be $expectedTags
            }
            It "Remove first tag" {
                $expectedTags = @($testTag4)

                [SfProject]$proj = (sf-project-get -all)[0]
                $result = sf-project-setCurrent $proj
                sf-project-tags-remove -tagName $testTag1

                [SfProject]$proj = (sf-project-get -all)[0]
                $result = sf-project-setCurrent $proj
                $proj.tags | Should -Be $expectedTags
                sf-project-tags-get | Should -Be $expectedTags
            }
            It "Remove last tag" {
                $expectedTags = @($testTag4)
                sf-project-tags-add -tagName $testTag2

                [SfProject]$proj = (sf-project-get -all)[0]
                $result = sf-project-setCurrent $proj
                sf-project-tags-remove -tagName $testTag2

                [SfProject]$proj = (sf-project-get -all)[0]
                $result = sf-project-setCurrent $proj
                $proj.tags | Should -Be $expectedTags
                sf-project-tags-get | Should -Be $expectedTags
            }
            It "Remove last remaining tag then adding one again" {
                [SfProject]$proj = (sf-project-get -all)[0]
                sf-project-setCurrent $proj
                sf-project-tags-remove -tagName $testTag4

                [SfProject]$proj = (sf-project-get -all)[0]
                sf-project-setCurrent $proj
                $proj.tags | Should -BeNullOrEmpty
                sf-project-tags-get | Should -BeNullOrEmpty

                $expectedTags = @($testTag4)
                sf-project-tags-add -tagName $testTag4

                [SfProject]$proj = (sf-project-get -all)[0]
                sf-project-setCurrent $proj
                sf-project-tags-get | Should -Be $expectedTags
            }
            It "Not accept tags starting with '-'" {
                { sf-project-tags-add -tagName "_ffd" } | Should -Throw -ExpectedMessage "Invalid tag name."
            }
            It "Not accept tags with spaces" {
                { sf-project-tags-add -tagName "dffd dfds" } | Should -Throw -ExpectedMessage "Invalid tag name."
            }
            It "Not accept Null or empty tags" {
                { sf-project-tags-add -tagName "   " } | Should -Throw -ExpectedMessage "Invalid tag name."
                { sf-project-tags-add -tagName "" } | Should -Throw -ExpectedMessage "Invalid tag name."
                { sf-project-tags-add -tagName $null } | Should -Throw -ExpectedMessage "Invalid tag name."
            }

        }
    }

    # Describe "_tag-setNewProjectDefaultTags should" {
    #     $Script:filter = $null
    #     Mock sf-project-tags-getDefaultFilter {
    #         $Script:filter
    #     }

    #     $test = {
    #         [SfProject]$p = _newSfProjectObject -id 'testId'
    #         _tag-setNewProjectDefaultTags -project $p
    #         $p.tags
    #     }

    #     It "set none tags when default tags filter has not been set" {
    #         $result = Invoke-Command -ScriptBlock $test
    #         $result | Should -BeNullOrEmpty
    #     }
    #     It "set none tags when default tags filter is empty" {
    #         $Script:filter = @()
    #         $result = Invoke-Command -ScriptBlock $test
    #         $result | Should -BeNullOrEmpty
    #     }
    #     It "set none tags when default tags filter has only exclude tags" {
    #         $Script:filter = @('_se1', '_e2')
    #         $result = Invoke-Command -ScriptBlock $test
    #         $result | Should -BeNullOrEmpty
    #     }
    #     It "set none tags when default tags filter has one exclude tags" {
    #         $Script:filter = @('_e1')
    #         $result = Invoke-Command -ScriptBlock $test
    #         $result | Should -BeNullOrEmpty
    #     }
    #     It "set only include tags when default tags filter has both include and exclude tags" {
    #         $Script:filter = @('_e1', 'i1', '_e3', 'i2')
    #         $result = Invoke-Command -ScriptBlock $test
    #         $result | Should -Contain 'i1'
    #         $result | Should -Contain 'i2'
    #         $result | Should -Not -Contain 'e1'
    #         $result | Should -Not -Contain '_e1'
    #         $result | Should -Not -Contain 'e3'
    #         $result | Should -Not -Contain '_e3'
    #         $result | Should -HaveCount 2
    #     }
    #     It "set only include tags when default tags filter has one include tag" {
    #         $Script:filter = @('i1')
    #         $result = Invoke-Command -ScriptBlock $test
    #         $result | Should -Contain 'i1'
    #         $result | Should -HaveCount 1
    #     }
    #     It "set only include tags when default tags filter has only include tags" {
    #         $Script:filter = @('i1', 'i2', 'i3')
    #         $result = Invoke-Command -ScriptBlock $test
    #         $result | Should -Contain 'i1'
    #         $result | Should -Contain 'i2'
    #         $result | Should -Contain 'i3'
    #         $result | Should -HaveCount 3
    #     }
    # }

    Describe "default tags operations" {
        InTestProjectScope {

            It "adds tag to default tag filter" {
                $filter = sf-project-tags-getDefaultFilter
                $filter += @("t1")
                sf-project-tags-setDefaultFilter $filter
                sf-project-tags-getDefaultFilter | Should -Be @("t1")
                $filter += @("t2")
                sf-project-tags-setDefaultFilter $filter
                $filter = sf-project-tags-getDefaultFilter
                $filter[0] | Should -Be "t1"
                $filter[1] | Should -Be "t2"
            }
            It "removes tag from default tags filter" {
                sf-project-tags-removeFromDefaultFilter -tag "t1"
                $filter = sf-project-tags-getDefaultFilter
                $filter[0] | Should -Be "t2"
            }
            It "removes nonexisting tag does nothing" {
                sf-project-tags-removeFromDefaultFilter -tag "t1"
                $filter = sf-project-tags-getDefaultFilter
                $filter[0] | Should -Be "t2"
            }
            It "removes all tags then add tags again" {
                sf-project-tags-removeFromDefaultFilter -tag "t2"
                $result = sf-project-tags-getDefaultFilter
                $result | Should -Be @()
                sf-project-tags-addToDefaultFilter -tag "t3"
                sf-project-tags-addToDefaultFilter -tag "t4"
                (sf-project-tags-getDefaultFilter)[0] | Should -Be "t3"
                (sf-project-tags-getDefaultFilter)[1] | Should -Be "t4"
            }

        }
    }
}
