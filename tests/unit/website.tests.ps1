. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    
    Mock execute-native { }
    . "$PSScriptRoot\init.ps1"
    
    Describe "sf-browse-webSite"  {
        It "do not open browser when no sitefinity selected" {
            Mock get-currentProject { $null }
            { browse-webSite } | Should -Throw "No project selected."
            Assert-MockCalled execute-native -Times 0 -Scope It
        }
    }
}