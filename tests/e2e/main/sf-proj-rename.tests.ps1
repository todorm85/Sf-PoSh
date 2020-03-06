. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    Describe "Rename should" -Tags ("rename") {
        It "change the display name and domain" {
            [SfProject]$testProject = set-testProject
            $id = $testProject.id
            $oldName = generateRandomName
            sd-project-rename $oldName
            $oldName = generateRandomName
            sd-project-rename $oldName
            $newName = generateRandomName

            Test-Path "$($testProject.solutionPath)\$newName($id).sln" | Should -Be $false
            Test-Path "$($testProject.solutionPath)\$oldName($id).sln" | Should -Be $true

            sd-iisSite-getUrl | ? { $_.Contains($oldName) } | Should -Not -BeNullOrEmpty
            os-hosts-get | ? { $_.Contains($oldName) } | Should -Not -BeNullOrEmpty
            os-hosts-get | ? { $_.Contains($newName) } | Should -BeNullOrEmpty

            sd-project-rename $newName

            Test-Path "$($testProject.solutionPath)\$newName($id).sln" | Should -Be $true
            Test-Path "$($testProject.solutionPath)\$oldName($id).sln" | Should -Be $false

            sd-iisSite-getUrl | ? { $_.Contains($newName) } | Should -Not -BeNullOrEmpty
            os-hosts-get | ? { $_.Contains($oldName) } | Should -BeNullOrEmpty
            os-hosts-get | ? { $_.Contains($newName) } | Should -Not -BeNullOrEmpty

            sd-project-rename $oldName
        }
    }
}
