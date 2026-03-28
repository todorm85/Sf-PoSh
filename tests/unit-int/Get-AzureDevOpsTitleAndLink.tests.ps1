. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {
    $linkRoute = "https://prgs-sitefinity.visualstudio.com/sitefinity/_workitems/edit/"

    Describe "_getNameParts should" {
        It "return same name when not from azure dev ops" {
            $testName = "custom name";
            $res = _getNameParts -name $testName
            $res.name | Should -Be $testName
            $res.link | Should -BeNullOrEmpty
        }
        It "return correct title and link for valid azure dev ops PBI title" {
            $testName = "Product Backlog Item 337271: 1 All classifications: screen_ *4448 55bs"
            $testName = $testName + ("a" * 50)
            $res = _getNameParts -name $testName
            $res.name | Should -BeLike "1 All classifications screen_ *4448 55bs*"
            # $res.name.Length | Should -BeLessThan 51
            $res.link | Should -Be "$($linkRoute)337271"
        }
        It "return correct title for valid azure dev ops BUG title" {
            $testName = "Bug 337271: 1 All classifications: screen_ *4448 55bs"
            $res = _getNameParts -name $testName
            $res.name | Should -BeLike "1 All classifications screen_ *4448 55bs"
        }
        It "return correct title for valid azure dev ops Task title" {
            $testName = "Task 337271: 1 All classifications: screen_ *4448 55bs"
            $res = _getNameParts -name $testName
            $res.name | Should -BeLike "1 All classifications screen_ *4448 55bs"
        }
        It "return correct title for valid azure dev ops BUG title that ends with invalid character" {
            $testName = "Bug 343346: Audit should not log the event when a frontend user signs in using frontend login widget."
            $res = _getNameParts -name $testName
            $res.name | Should -BeLike "Audit should not log the event when a frontend user signs in using frontend login widget."
        }
        It "return correct title for valid azure dev ops CUSTOM title" {
            $GLOBAL:sf.config.azureDevOpsItemTypes += @("Custom title")
            $testName = "Custom title 343346: Audit should not log the event when a frontend user signs in using frontend login widget."
            $res = _getNameParts -name $testName
            $res.name | Should -BeLike "Audit should not log the event when a frontend user signs in using frontend login widget."
        }
    }
}
