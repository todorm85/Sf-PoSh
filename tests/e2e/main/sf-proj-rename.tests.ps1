. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    Describe "Rename should" -Tags ("rename") {
        It "change the display name and domain" {
            [SfProject]$testProject = set-testProject
            $id = $testProject.id
            $oldName = "$($testProject.displayName)"
            $newName = generateRandomName

            Test-Path "$($GLOBAL:sf.Config.projectsDirectory)\$id\$newName($id).sln" | Should -Be $false

            sd-project-rename $newName

            Test-Path "$($testProject.solutionPath)\$newName($id).sln" | Should -Be $true
            Test-Path "$($testProject.solutionPath)\$oldName($id).sln" | Should -Be $false

            sd-project-rename $oldName
        }
    }
}
