. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {
    
    Mock execute-native { }
    . "$PSScriptRoot\init.ps1"
    
    Describe "sf-sf-iis-site-open"  {
        It "do not open browser when no sitefinity selected" {
            Mock sf-proj-getCurrent { $null }
            { sf-iis-site-open } | Should -Throw "No project selected."
            Assert-MockCalled execute-native -Times 0 -Scope It
        }
    }
}
