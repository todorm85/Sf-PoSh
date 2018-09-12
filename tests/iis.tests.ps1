Import-Module sf-dev

InModuleScope sf-dev {
    . "${PSScriptRoot}\init-tests.ps1"

    Describe "iis-show-appPoolPid should" {
        It "return process ids correctly" {
            $res = iis-show-appPoolPid
            { iis-show-appPoolPid } | Should -Not -Throw
        }
    }
}