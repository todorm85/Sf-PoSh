. "${PSScriptRoot}\load.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"
    Describe "test" {
        . "$PSScriptRoot\test-project-init.ps1"
        It "case" {

        }

        . "$PSScriptRoot\test-project-teardown.ps1"
    }
}