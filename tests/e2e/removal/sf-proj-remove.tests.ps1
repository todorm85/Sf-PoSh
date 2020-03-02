. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"

    Describe "Remove should" -Tags ("delete") {
        It "remove all" {
            [SfProject]$proj = set-testProject
            $testId = $proj.id
            
            sd-project-remove -noPrompt
            
            $sitefinities = @(sd-project-getAll) | Where-Object { $_.id -eq $testId }
            $sitefinities | Should -HaveCount 0
            Test-Path "$($GLOBAL:sf.Config.projectsDirectory)\${testId}" | Should -Be $false
            Test-Path "IIS:\AppPools\${testId}" | Should -Be $false
            Test-Path "IIS:\Sites\${testId}" | Should -Be $false
            sql-get-dbs | Where-Object { $_.Name.Contains($testId) } | Should -HaveCount 0
            existsInHostsFile -searchParam "$($proj.displayName)_$($proj.id)" | Should -Be $false
            tfs-get-workspaces $GLOBAL:sf.Config.tfsServerName | Where-Object { $_ -like "*$testId*" } | Should -HaveCount 0
        }
    }
}
