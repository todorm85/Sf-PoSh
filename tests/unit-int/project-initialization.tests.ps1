. "${PSScriptRoot}\load.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "test" {
        . "$PSScriptRoot\test-project-init.ps1"

        It "project is not initialized when using the api" {
            [SfProject]$p = sd-project-getCurrent
            $p.websiteName | Should -Not -BeNullOrEmpty
            $p.websiteName = ''
            sd-project-save $p
            [SfProject]$p = sd-project-getCurrent
            $p.websiteName | Should -BeNullOrEmpty
            [SfProject]$p = sd-project-getAll | select -First 1
            $p.websiteName | Should -BeNullOrEmpty
        }

        It "project is initialized when using select from the prompt" {
            [SfProject]$p = sd-project-getAll | select -First 1
            Mock _promptProjectSelect {
                $p
            }

            sf-select
            [SfProject]$p = sd-project-getCurrent
            $p.websiteName | Should -Not -BeNullOrEmpty
        }

        . "$PSScriptRoot\test-project-teardown.ps1"
    }
}