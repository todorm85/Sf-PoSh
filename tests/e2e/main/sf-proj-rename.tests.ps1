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
            Test-Path "$($GLOBAL:sf.Config.projectsDirectory)\$id\$newName($id).sln" | Should -Be $false
            existsInHostsFile -searchParam $oldName | Should -Be $true

            sd-project-rename $newName
            
            existsInHostsFile -searchParam $newName | Should -Be $true
            Test-Path "$($testProject.solutionPath)\$newName($id).sln" | Should -Be $true
            Test-Path "$($testProject.solutionPath)\$oldName($id).sln" | Should -Be $false
            ([string](sd-iisSite-getUrl)).IndexOf($newName) | Should -BeGreaterThan -1

            sd-project-rename $oldName
            existsInHostsFile -searchParam $newName | Should -Be $false
        }
    }
}
