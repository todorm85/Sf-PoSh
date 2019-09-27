. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    
    Describe "Rename should" -Tags ("rename") {
        It "change the display name and domain" {
            [SfProject]$testProject = set-testProject
            $id = $testProject.id
            $oldName = "$($testProject.displayName)"
            $newName = generateRandomName

            existsInHostsFile -searchParam $newName | Should -Be $false
            Test-Path "$($GLOBAL:Sf.Config.projectsDirectory)\$id\$newName($id).sln" | Should -Be $false
            existsInHostsFile -searchParam $oldName | Should -Be $true

            sf-proj-rename $newName
            
            existsInHostsFile -searchParam $newName | Should -Be $true
            existsInHostsFile -searchParam $oldName | Should -Be $false
            Test-Path "$($testProject.solutionPath)\$newName($id).sln" | Should -Be $true
            Test-Path "$($testProject.solutionPath)\$oldName($id).sln" | Should -Be $false
            ([string](_getAppUrl)).IndexOf($newName) | Should -BeGreaterThan -1

            sf-proj-rename $oldName
        }
    }
}
