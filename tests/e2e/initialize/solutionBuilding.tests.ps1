. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    It "when building succeed after at least 3 retries" {
        Set-TestProject
        sol-build -retryCount 3
    }
}
