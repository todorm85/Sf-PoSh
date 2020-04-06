. "${PSScriptRoot}\load.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "test" {
        . "$PSScriptRoot\test-project-init.ps1"

        [SfProject]$p = sd-project-getCurrent
        $oldWebsiteName = $p.websiteName
        $oldSolPath = $p.solutionPath
        It "project is not initialized when using the api" {
            $p.websiteName | Should -Not -BeNullOrEmpty
            $p.websiteName = 'wrongName'
            $p.solutionPath = 'dummyPath'
            sd-project-save $p
            [SfProject]$p = sd-project-getCurrent
            $p.websiteName | Should -Be 'wrongName'
            $p.solutionPath | Should -Be 'dummyPath'
            [SfProject]$p = sd-project-getAll | select -First 1
            $p.websiteName | Should -Be 'wrongName'
            $p.solutionPath | Should -Be 'dummyPath'
        }

        It "project is initialized when using select from the prompt" {
            [SfProject]$p = sd-project-getAll | select -First 1
            Mock _promptProjectSelect {
                $p
            }

            sd-project-select
            [SfProject]$p = sd-project-getCurrent
            $p.websiteName | Should -Be $oldWebsiteName
            $p.solutionPath | Should -Be $oldSolPath
        }

        . "$PSScriptRoot\test-project-teardown.ps1"
    }
}