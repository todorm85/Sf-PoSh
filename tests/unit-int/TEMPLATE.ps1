. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {
    . "$PSScriptRoot\init.ps1"
    Describe "test" {
        . "$PSScriptRoot\test-project-init.ps1"
        It "case" {

        }

        . "$PSScriptRoot\test-project-teardown.ps1"
    }
}