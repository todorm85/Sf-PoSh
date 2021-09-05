. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {
    
    Describe "Tags should" -Tags ("fluent") {
        InTestProjectScope {

            $testTag1 = 'test-sd-projectTags-1'
            $testTag2 = 'test-sd-projectTags-2'
            $testTag3 = 'test-sd-projectTags-3'
            $testTag4 = 'test-sd-projectTags-4'

            It "Add single tag to project" {
                sf-PSproject-tags-add -tagName $testTag1
                [SfProject]$proj = (sf-PSproject-get -all)[0]
                $proj.tags | Should -Contain $testTag1
                $result = sf-PSproject-setCurrent $proj
                sf-PSproject-tags-get | Should -Contain $testTag1
                sf-PSproject-tags-get | Should -HaveCount 1
            }
            It "Add multiple tags to project" {
                $expectedTags = @($testTag1, $testTag2, $testTag3)
                sf-PSproject-tags-add -tagName $testTag2
                sf-PSproject-tags-add -tagName $testTag3
                [SfProject]$proj = (sf-PSproject-get -all)[0]
                $proj.tags | Should -Be $expectedTags
                $result = sf-PSproject-setCurrent $proj
                sf-PSproject-tags-get | Should -Be $expectedTags
            }
            It "Remove tag from project" {
                $expectedTags = @($testTag1, $testTag3)

                [SfProject]$proj = (sf-PSproject-get -all)[0]
                $result = sf-PSproject-setCurrent $proj
                sf-PSproject-tags-remove -tagName $testTag2

                [SfProject]$proj = (sf-PSproject-get -all)[0]
                $result = sf-PSproject-setCurrent $proj
                $proj.tags | Should -Be $expectedTags
                sf-PSproject-tags-get | Should -Be $expectedTags
            }
            It "Remove multiple tags from project" {
                $expectedTags = @($testTag1, $testTag4)
                sf-PSproject-tags-add -tagName $testTag2
                sf-PSproject-tags-add -tagName $testTag4

                [SfProject]$proj = (sf-PSproject-get -all)[0]
                $result = sf-PSproject-setCurrent $proj
                sf-PSproject-tags-remove -tagName $testTag2
                sf-PSproject-tags-remove -tagName $testTag3

                [SfProject]$proj = (sf-PSproject-get -all)[0]
                $result = sf-PSproject-setCurrent $proj
                $proj.tags | Should -Be $expectedTags
                sf-PSproject-tags-get | Should -Be $expectedTags
            }
            It "Remove first tag" {
                $expectedTags = @($testTag4)

                [SfProject]$proj = (sf-PSproject-get -all)[0]
                $result = sf-PSproject-setCurrent $proj
                sf-PSproject-tags-remove -tagName $testTag1

                [SfProject]$proj = (sf-PSproject-get -all)[0]
                $result = sf-PSproject-setCurrent $proj
                $proj.tags | Should -Be $expectedTags
                sf-PSproject-tags-get | Should -Be $expectedTags
            }
            It "Remove last tag" {
                $expectedTags = @($testTag4)
                sf-PSproject-tags-add -tagName $testTag2

                [SfProject]$proj = (sf-PSproject-get -all)[0]
                $result = sf-PSproject-setCurrent $proj
                sf-PSproject-tags-remove -tagName $testTag2

                [SfProject]$proj = (sf-PSproject-get -all)[0]
                $result = sf-PSproject-setCurrent $proj
                $proj.tags | Should -Be $expectedTags
                sf-PSproject-tags-get | Should -Be $expectedTags
            }
            It "Remove last remaining tag then adding one again" {
                [SfProject]$proj = (sf-PSproject-get -all)[0]
                sf-PSproject-setCurrent $proj
                sf-PSproject-tags-remove -tagName $testTag4

                [SfProject]$proj = (sf-PSproject-get -all)[0]
                sf-PSproject-setCurrent $proj
                $proj.tags | Should -BeNullOrEmpty
                sf-PSproject-tags-get | Should -BeNullOrEmpty

                $expectedTags = @($testTag4)
                sf-PSproject-tags-add -tagName $testTag4

                [SfProject]$proj = (sf-PSproject-get -all)[0]
                sf-PSproject-setCurrent $proj
                sf-PSproject-tags-get | Should -Be $expectedTags
            }
            It "Not accept tags starting with '-'" {
                { sf-PSproject-tags-add -tagName "_ffd" } | Should -Throw -ExpectedMessage "Invalid tag name."
            }
            It "Not accept tags with spaces" {
                { sf-PSproject-tags-add -tagName "dffd dfds" } | Should -Throw -ExpectedMessage "Invalid tag name."
            }
            It "Not accept Null or empty tags" {
                { sf-PSproject-tags-add -tagName "   " } | Should -Throw -ExpectedMessage "Invalid tag name."
                { sf-PSproject-tags-add -tagName "" } | Should -Throw -ExpectedMessage "Invalid tag name."
                { sf-PSproject-tags-add -tagName $null } | Should -Throw -ExpectedMessage "Invalid tag name."
            }

        }
    }

    # Describe "_tag-setNewProjectDefaultTags should" {
    #     $Script:filter = $null
    #     Mock sf-PSproject-tags-getDefaultFilter {
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
                $filter = sf-PSproject-tags-getDefaultFilter
                $filter += @("t1")
                sf-PSproject-tags-setDefaultFilter $filter
                sf-PSproject-tags-getDefaultFilter | Should -Be @("t1")
                $filter += @("t2")
                sf-PSproject-tags-setDefaultFilter $filter
                $filter = sf-PSproject-tags-getDefaultFilter
                $filter[0] | Should -Be "t1"
                $filter[1] | Should -Be "t2"
            }
            It "removes tag from default tags filter" {
                sf-PSproject-tags-removeFromDefaultFilter -tag "t1"
                $filter = sf-PSproject-tags-getDefaultFilter
                $filter[0] | Should -Be "t2"
            }
            It "removes nonexisting tag does nothing" {
                sf-PSproject-tags-removeFromDefaultFilter -tag "t1"
                $filter = sf-PSproject-tags-getDefaultFilter
                $filter[0] | Should -Be "t2"
            }
            It "removes all tags then add tags again" {
                sf-PSproject-tags-removeFromDefaultFilter -tag "t2"
                $result = sf-PSproject-tags-getDefaultFilter
                $result | Should -Be @()
                sf-PSproject-tags-addToDefaultFilter -tag "t3"
                sf-PSproject-tags-addToDefaultFilter -tag "t4"
                (sf-PSproject-tags-getDefaultFilter)[0] | Should -Be "t3"
                (sf-PSproject-tags-getDefaultFilter)[1] | Should -Be "t4"
            }

        }
    }
}
