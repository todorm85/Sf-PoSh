. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {

    Describe "Project initialization should" {
        InTestProjectScope {

            [SfProject]$p = sf-PSproject-get
            $oldWebsiteName = $p.websiteName
            $oldSolPath = $p.solutionPath
            It "not initialize when using the api" {
                $p.websiteName | Should -Not -BeNullOrEmpty
                $p.websiteName = 'wrongName'
                $p.solutionPath = 'dummyPath'
                sf-PSproject-save $p
                [SfProject]$p = sf-PSproject-get
                $p.websiteName | Should -Be 'wrongName'
                $p.solutionPath | Should -Be 'dummyPath'
                [SfProject]$p = sf-PSproject-get -all | select -First 1
                $p.websiteName | Should -Be 'wrongName'
                $p.solutionPath | Should -Be 'dummyPath'
            }

            It "initialize when using select from the prompt and not in cache" {
                [SfProject]$p = sf-PSproject-get -all | select -First 1
                $p.websiteName = 'wrongName2'
                $p.solutionPath = 'dummyPath2'
                $Global:mockedProject = $p
                Mock _proj-promptSelect {
                    $Global:mockedProject
                }

                sf-PSproject-select
                [SfProject]$p = sf-PSproject-get
                $p.websiteName | Should -Be $oldWebsiteName
                $p.solutionPath | Should -Be $oldSolPath
            }

        }
    }
}