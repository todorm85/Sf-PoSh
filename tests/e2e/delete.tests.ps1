. "$PSScriptRoot\init.ps1"

. "$testUtilsDir\load-module.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    Describe "Delete should" -Tags ("delete") {
        It "remove all" {
            [SfProject]$proj = set-testProject
            $testId = $proj.id
            
            $Global:sf.project.Delete()
            
            $sitefinities = @(sf-get-allProjects -skipInit) | where { $_.id -eq $testId }
            $sitefinities | Should -HaveCount 0
            Test-Path "$($Script:projectsDirectory)\${testId}" | Should -Be $false
            Test-Path "IIS:\AppPools\${testId}" | Should -Be $false
            Test-Path "IIS:\Sites\${testId}" | Should -Be $false
            $sql.GetDbs() | Where-Object { $_.Name.Contains($testId) } | Should -HaveCount 0
            existsInHostsFile -searchParam "$($proj.displayName)_$($proj.id)" | Should -Be $false
        }
    }
}