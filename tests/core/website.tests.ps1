. "${PSScriptRoot}\Infrastructure\load-module.ps1"

InModuleScope sf-dev {
    
    Mock execute-native { }
    
    Describe "sf-browse-webSite"  {
        It "do not open browser when no sitefinity selected" {
            Mock _get-selectedProject { $null }
            { sf-browse-webSite } | Should -Throw "No project selected."
            Assert-MockCalled execute-native -Times 0 -Scope It
        }
    }
}