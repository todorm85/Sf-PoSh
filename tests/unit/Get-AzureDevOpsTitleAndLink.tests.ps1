. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    $linkRoute = "https://prgs-sitefinity.visualstudio.com/sitefinity/_workitems/edit/"

    Describe "GetAzureDevOpsTitleAndLink should" {
        It "return same name when not from azure dev ops" {
            $testName = "custom name";
            $res = GetAzureDevOpsTitleAndLink -name $testName
            $res.name | Should -Be $testName
            $res.link | Should -BeNullOrEmpty
        }
        It "return correct title and link for valid azure dev ops PBI title" {
            $testName = "Product Backlog Item 337271: 1 All classifications: screen_ *4448 55bs"
            $testName = $testName + ("a" * 50)
            $res = GetAzureDevOpsTitleAndLink -name $testName
            $res.name | Should -BeLike "All_classifications_screen__4448_55bs*"
            $res.name.Length | Should -BeLessThan 51
            $res.link | Should -Be "$($linkRoute)337271"
        }
        It "return correct title for valid azure dev ops BUG title" {
            $testName = "Bug 337271: 1 All classifications: screen_ *4448 55bs"
            $res = GetAzureDevOpsTitleAndLink -name $testName
            $res.name | Should -BeLike "All_classifications_screen__4448_55bs"
        }
        It "return correct title for valid azure dev ops Task title" {
            $testName = "Task 337271: 1 All classifications: screen_ *4448 55bs"
            $res = GetAzureDevOpsTitleAndLink -name $testName
            $res.name | Should -BeLike "All_classifications_screen__4448_55bs"
        }
    }
}