. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {

    Mock execute-native { }

    Describe "sf-iisSite-browse"  {
        It "do not open browser when no sitefinity selected" {
            Mock sf-project-get { $null }
            { sf-iisSite-browse } | Should -Throw "No project selected."
            Assert-MockCalled execute-native -Times 0 -Scope It
        }
    }
}
