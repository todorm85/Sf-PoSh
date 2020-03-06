. "${PSScriptRoot}\..\test-utils\load-module.ps1"

InModuleScope sf-dev {

    Mock execute-native { }
    . "$PSScriptRoot\init.ps1"

    Describe "sd-iisSite-browse"  {
        It "do not open browser when no sitefinity selected" {
            Mock sd-project-getCurrent { $null }
            { sd-iisSite-browse } | Should -Throw "No project selected."
            Assert-MockCalled execute-native -Times 0 -Scope It
        }
    }
}
