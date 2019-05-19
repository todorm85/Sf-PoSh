. "$PSScriptRoot\init.ps1"

. "$testUtilsDir\load-module.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    
    Describe "Rename should" -Tags ("rename") {
        It "change the display name and domain" {
            [SfProject]$testProject = set-testProject
            $id = $testProject.id
            $oldName = $testProject.displayName
            $newName = generateRandomName

            existsInHostsFile -searchParam $newName | Should -Be $false
            Test-Path "$($Script:projectsDirectory)\$id\$newName($id).sln" | Should -Be $false
            existsInHostsFile -searchParam $newName | Should -Be $false

            $Global:sf.project.Rename($newName)
            
            existsInHostsFile -searchParam $newName | Should -Be $true
            existsInHostsFile -searchParam $oldName | Should -Be $false
            Test-Path "$($Script:projectsDirectory)\$id\$newName($id).sln" | Should -Be $true
            Test-Path "$($Script:projectsDirectory)\$id\$oldName($id).sln" | Should -Be $false
            ([string](get-appUrl)).IndexOf($newName) | Should -BeGreaterThan -1
        }
    }
}