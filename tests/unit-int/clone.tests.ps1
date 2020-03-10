. "${PSScriptRoot}\load.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "Cloning project should" {
        . "$PSScriptRoot\test-project-init.ps1"
        $sourceProj = sd-project-getCurrent

        $sourceName = $sourceProj.displayName
        $cloneTestName = "$sourceName-clone" # TODO: stop using hardcoded convention here

        sd-project-getAll | Where-Object displayName -eq $cloneTestName | ForEach-Object {
            sd-project-remove -noPrompt -context $_
        }

        $dbName = sd-db-getNameFromDataConfig
        sql-get-dbs | Where-Object { $_.name -eq $dbName } | Should -HaveCount 1

        sd-project-clone

        [SfProject]$project = sd-project-getCurrent
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

        $projects | ForEach-Object {
            sd-project-remove -noPrompt -context $_
        }

        . "$PSScriptRoot\test-project-teardown.ps1"
    }
}