. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    It "start the app correctly" {
        set-testProject
        sf-app-reset -start
        $url = _getAppUrl
        $result = _invokeNonTerminatingRequest $url
        $result | Should -Be 200
    }
}
