. "${PSScriptRoot}\..\Infrastructure\load-module.ps1"

InModuleScope sf-dev.dev {
    
    Describe "_sfData-get-allProjects" {
        $oldDataPath

        BeforeAll {
            $oldDataPath = $Global:dataPath
            $Global:dataPath = "$($Global:prjectsDirectory)\data-tests-db.xml"
            if (Test-Path $dataPath) {
                Remove-Item $dataPath -Force
            }
            else {
                . "E:\sf-dev\module\core\manager\manager.init.ps1"
            }
        }

        It "return empty collection when no projects" {
            $projects = _sfData-get-allProjects
            $projects | Should -HaveCount 0
        }

        It "return correct count of projects" {
            $proj1 = New-Object SfProject -Property @{
                branch        = "test-branch";
                containerName = "test-container";
                id            = "id1";
            }

            _sfData-save-project -context $proj1
            [SfProject[]]$projects = _sfData-get-allProjects
            $projects | Should -HaveCount 1
            $projects[0].id | Should -Be "id1"
            $projects[0].branch | Should -Be "test-branch"
            $projects[0].containerName | Should -Be "test-container"
        }

        It "return correct count of projects when many" {
            $proj1 = New-Object SfProject -Property @{
                branch        = "test-branch";
                containerName = "test-container";
                id            = "id1";
            }

            _sfData-save-project -context $proj1
            $proj1.id = 'id2'
            _sfData-save-project -context $proj1

            [SfProject[]]$projects = _sfData-get-allProjects
            $projects | Should -HaveCount 2
            $projects[0].id | Should -Be "id1"
            $projects[1].id | Should -Be "id2"
            $projects[0].branch | Should -Be "test-branch"
            $projects[0].containerName | Should -Be "test-container"
        }

        AfterAll {
            try {
                Write-Host "Module test db cleanup"
                Remove-Item $Global:dataPath
            }
            catch {
                Write-Warning "Module db file was not cleaned up: $_"
            }
            finally {
                $Global:dataPath = $oldDataPath
            }
        }

    }
}