. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {

    Mock execute-native { }

    Describe "sf-iis-site-browse"  {
        It "do not open browser when no sitefinity selected" {
            Mock sf-PSproject-get { $null }
            { sf-iis-site-browse } | Should -Throw "No project selected."
            Assert-MockCalled execute-native -Times 0 -Scope It
        }
    }
}
