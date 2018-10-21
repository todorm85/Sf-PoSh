. "${PSScriptRoot}\..\Infrastructure\load-module.ps1"

InModuleScope sf-dev {

    Describe "iis-show-appPoolPid should" {
        It "return process ids correctly" {
            $res = iis-show-appPoolPid
            { iis-show-appPoolPid } | Should -Not -Throw
        }
    }
}