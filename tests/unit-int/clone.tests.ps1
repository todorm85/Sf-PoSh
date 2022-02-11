. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {
    Describe "Cloning project should" {
        InTestProjectScope {
            $sourceProj = sf-project-get

            $sourceName = $sourceProj.displayName
            $cloneTestName = "$sourceName-clone" # TODO: stop using hardcoded convention here

            sf-project-get -all | Where-Object displayName -eq $cloneTestName | ForEach-Object {
                sf-project-remove -project $_ -noPrompt
            }

            $dbName = sf-db-getNameFromDataConfig
            sql-get-dbs | Where-Object { $_.name -eq $dbName } | Should -HaveCount 1
            
            It "clone the project without throwing" {
                sf-project-clone
            }

            [SfProject]$project = sf-project-get
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
                $project.solutionPath.ToLower().Contains($GLOBAL:sf.Config.projectsDirectory.ToLower()) | Should -Be $true
            }

            It "set project site" {
                $project.websiteName | Should -Be $cloneTestId
            }

            It "create project solution directory" {
                Test-Path $project.solutionPath | Should -Be $true
            }

            It "create a hosts file entry" {
                existsInHostsFile -searchParam $project.id | Should -Be $true
            }

            It "create a user friendly solution name" {
                Test-Path "$($project.solutionPath)\$($project.id).sln" | Should -Be $true
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
                $old = sf-project-get
                $old.tags.Add("test")
                $oldDb = sf-db-getNameFromDataConfig
                sf-project-clone -skipDatabaseClone
                $p = sf-project-get
                sql-get-dbs | Where-Object { $_.name -eq $p.id } | Should -HaveCount 0
                sql-get-dbs | Where-Object { $_.name -eq $old.id } | Should -HaveCount 1
                sf-db-getNameFromDataConfig | Should -Be $oldDb
                $p.tags | Should -Contain "test"
                $old.tags.Add("test2")
                $p.tags | Should -HaveCount 1
            }

            $projects | ForEach-Object {
                sf-project-remove $_ -noPrompt
            }
        }
    }
}