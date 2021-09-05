. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {

    Describe "Rename should" -Tags ("rename") {
        It "change the display name and domain" {
            InTestProjectScope {
            [SfProject]$testProject = sf-PSproject-get
            $id = $testProject.id
            $oldName = generateRandomName
            sf-PSproject-rename $oldName
            $oldName = generateRandomName
            sf-PSproject-rename $oldName
            $newName = generateRandomName

            Test-Path "$($testProject.solutionPath)\$newName($id).sln" | Should -Be $false
            Test-Path "$($testProject.solutionPath)\$oldName($id).sln" | Should -Be $true

            sf-iis-site-getUrl | ? { $_.Contains($oldName) } | Should -Not -BeNullOrEmpty
            os-hosts-get | ? { $_.Contains($oldName) } | Should -Not -BeNullOrEmpty
            os-hosts-get | ? { $_.Contains($newName) } | Should -BeNullOrEmpty

            sf-PSproject-rename $newName

            Test-Path "$($testProject.solutionPath)\$newName($id).sln" | Should -Be $true
            Test-Path "$($testProject.solutionPath)\$oldName($id).sln" | Should -Be $false

            sf-iis-site-getUrl | ? { $_.Contains($newName) } | Should -Not -BeNullOrEmpty
            os-hosts-get | ? { $_.Contains($oldName) } | Should -BeNullOrEmpty
            os-hosts-get | ? { $_.Contains($newName) } | Should -Not -BeNullOrEmpty

            sf-PSproject-rename $oldName
        }

        }
    }
}
