. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

$pbiName = "Product Backlog Item 337271: 1 All classifications screen"
$bugName = "Bug 339999: It's possible to select related data item twice"
$taskName = "Task 340087: Cache the taxonomies per site result"
$linkRoute = "https://prgs-sitefinity.visualstudio.com/sitefinity/_workitems/edit/"

    Describe "Get-AzureDevOpsTitleAndLink should" {
        It "return same name when not from azure dev ops" {
            $testName = "custom name";
            $res = Get-AzureDevOpsTitleAndLink -name $testName
            $res.name | Should -Be $testName
            $res.link | Should -BeNullOrEmpty
        }
        It "return correct title and link for valid azure dev ops link" {
            $testName = "Product Backlog Item 337271: 1 All classifications: screen_ *4448 55bs"
            $testName = $testName + ("a" * 72)
            $res = Get-AzureDevOpsTitleAndLink -name $testName
            $res.name | Should -BeLike "All_classifications_screen__4448_55bs*"
            $res.name.Length | Should -BeLessThan 73
            $res.link | Should -Be "$($linkRoute)337271"
        }
    }
}