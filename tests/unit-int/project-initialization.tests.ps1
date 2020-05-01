. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {

    Describe "Project initialization should" {
        InTestProjectScope {

        [SfProject]$p = sf-project-getCurrent
        $oldWebsiteName = $p.websiteName
        $oldSolPath = $p.solutionPath
        It "not initialize when using the api" {
            $p.websiteName | Should -Not -BeNullOrEmpty
            $p.websiteName = 'wrongName'
            $p.solutionPath = 'dummyPath'
            sf-project-save $p
            [SfProject]$p = sf-project-getCurrent
            $p.websiteName | Should -Be 'wrongName'
            $p.solutionPath | Should -Be 'dummyPath'
            [SfProject]$p = sf-project-getAll | select -First 1
            $p.websiteName | Should -Be 'wrongName'
            $p.solutionPath | Should -Be 'dummyPath'
        }

        It "initialize when using select from the prompt" {
            [SfProject]$p = sf-project-getAll | select -First 1
            Mock _proj-promptSelect {
                $p
            }

            sf-project-select
            [SfProject]$p = sf-project-getCurrent
            $p.websiteName | Should -Be $oldWebsiteName
            $p.solutionPath | Should -Be $oldSolPath
        }

        }
    }
}