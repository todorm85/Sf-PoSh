. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {
    . "$PSScriptRoot\init.ps1"

    Describe "Cloning project should" {
        . "$PSScriptRoot\test-project-init.ps1"

        $sourceProj = sf-project-getCurrent

        $sourceName = $sourceProj.displayName
        $cloneTestName = "$sourceName-clone" # TODO: stop using hardcoded convention here

        sf-project-getAll | Where-Object displayName -eq $cloneTestName | ForEach-Object {
            sf-project-remove -context $_
        }

        $dbName = sf-db-getNameFromDataConfig
        sql-get-dbs | Where-Object { $_.name -eq $dbName } | Should -HaveCount 1

        sf-project-clone

        [SfProject]$project = sf-project-getCurrent
        $cloneTestId = $project.id

        It "save the cloned project in sfdev db" {
            _data-getAllProjects | Should -HaveCount 2
        }

        It "set the current project to the cloned" {
            $project.id | Should -Not -Be $sourceProj.id
        }

        It "set project displayName" {
            $project.displayName | Should -Be $cloneTestName
        }

        It "set project solution path" {
            $project.solutionPath.Contains($GLOBAL:sf.Config.projectsDirectory) | Should -Be $true
        }

        It "set project site" {
            $project.websiteName | Should -Be $cloneTestId
        }

        It "create project solution directory" {
            Test-Path $project.solutionPath | Should -Be $true
        }

        It "create a hosts file entry" {
            existsInHostsFile -searchParam $project.displayName | Should -Be $true
        }

        It "create a user friendly solution name" {
            Test-Path "$($project.solutionPath)\$($project.displayName)($($project.id)).sln" | Should -Be $true
        }

        It "copy the original solution file" {
            Test-Path "$($project.solutionPath)\Telerik.Sitefinity.sln" | Should -Be $true
        }

        It "create website pool" {
            Test-Path "IIS:\AppPools\${cloneTestId}" | Should -Be $true
        }

        It "create website" {
            Test-Path "IIS:\Sites\${cloneTestId}" | Should -Be $true
        }

        It "create a copy of db" {
            sql-get-dbs | Where-Object { $_.name -eq $cloneTestId } | Should -HaveCount 1
        }

        It "NOT create a copy of db when skipDb switch is passed" {
            $old = sf-project-getCurrent
            $old.tags.Add("test")
            $oldDb = sf-db-getNameFromDataConfig
            sf-project-clone -skipDatabaseClone
            $p = sf-project-getCurrent
            sql-get-dbs | Where-Object { $_.name -eq $p.id } | Should -HaveCount 0
            sql-get-dbs | Where-Object { $_.name -eq $old.id } | Should -HaveCount 1
            sf-db-getNameFromDataConfig | Should -Be $oldDb
            $p.tags | Should -Contain "test"
            $old.tags.Add("test2")
            $p.tags | Should -HaveCount 1
        }

        $projects | ForEach-Object {
            sf-project-remove -context $_
        }

        . "$PSScriptRoot\test-project-teardown.ps1"
    }
}