. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    Describe "Rename should" -Tags ("rename") {
        It "change the display name and domain" {
            Global:set-testProject -appPath (Get-PSDrive TestDrive).Root
            [SfProject]$testProject = sd-project-getCurrent
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

        Global:clean-testProjectLeftovers
    }
}
