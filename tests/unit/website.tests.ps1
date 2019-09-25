. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    
    Mock execute-native { }
    . "$PSScriptRoot\init.ps1"
    
    Describe "sf-Open-WebSite"  {
        It "do not open browser when no sitefinity selected" {
            Mock get-currentProject { $null }
            { Open-WebSite } | Should -Throw "No project selected."
            Assert-MockCalled execute-native -Times 0 -Scope It
        }
    }
}