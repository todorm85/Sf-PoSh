. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    
    Mock execute-native { }
    . "$PSScriptRoot\init.ps1"
    
    Describe "sf-srv-site-open"  {
        It "do not open browser when no sitefinity selected" {
            Mock proj-getCurrent { $null }
            { srv-site-open } | Should -Throw "No project selected."
            Assert-MockCalled execute-native -Times 0 -Scope It
        }
    }
}
