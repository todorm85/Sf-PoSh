. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    Describe "App start should" {
        It "start the app correctly" {
            set-testProject
            sf-app-reinitializeAndStart
            $url = url-get
            $result = _invokeNonTerminatingRequest $url
            $result | Should -Be 200
        }
    }
}
