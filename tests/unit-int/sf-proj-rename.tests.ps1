. "${PSScriptRoot}\load.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "Rename should" -Tags ("rename") {
        It "change the display name and domain" {
            . "$PSScriptRoot\test-project-init.ps1"
            [SfProject]$testProject = sf-project-getCurrent
            $id = $testProject.id
            $oldName = generateRandomName
            sf-project-rename $oldName
            $oldName = generateRandomName
            sf-project-rename $oldName
            $newName = generateRandomName

            Test-Path "$($testProject.solutionPath)\$newName($id).sln" | Should -Be $false
            Test-Path "$($testProject.solutionPath)\$oldName($id).sln" | Should -Be $true

            sf-iisSite-getUrl | ? { $_.Contains($oldName) } | Should -Not -BeNullOrEmpty
            os-hosts-get | ? { $_.Contains($oldName) } | Should -Not -BeNullOrEmpty
            os-hosts-get | ? { $_.Contains($newName) } | Should -BeNullOrEmpty

            sf-project-rename $newName

            Test-Path "$($testProject.solutionPath)\$newName($id).sln" | Should -Be $true
            Test-Path "$($testProject.solutionPath)\$oldName($id).sln" | Should -Be $false

            sf-iisSite-getUrl | ? { $_.Contains($newName) } | Should -Not -BeNullOrEmpty
            os-hosts-get | ? { $_.Contains($oldName) } | Should -BeNullOrEmpty
            os-hosts-get | ? { $_.Contains($newName) } | Should -Not -BeNullOrEmpty

            sf-project-rename $oldName
        }

        . "$PSScriptRoot\test-project-teardown.ps1"
    }
}
