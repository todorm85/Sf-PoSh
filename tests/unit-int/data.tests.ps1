. "$PSScriptRoot\load.ps1"

InModuleScope sf-posh {

    Describe "sf-project-getAll" {
        Mock _proj-initialize { }

        It "return empty collection when no projects" {
            sf-project-get -all | Should -HaveCount 0
        }

        It "return correct count of projects" {
            $proj1 = New-Object SfProject -Property @{
                id = "id1";
            }

            _setProjectData -context $proj1
            [SfProject[]]$projects = sf-project-get -all
            $projects | Should -HaveCount 1
            $projects[0].id | Should -Be "id1"
        }

        It "return correct count of projects when many" {
            $proj1 = New-Object SfProject -Property @{
                id = "id1";
            }

            _setProjectData -context $proj1
            $proj1.id = 'id2'
            _setProjectData -context $proj1

            [SfProject[]]$projects = sf-project-get -all
            $projects | Should -HaveCount 2
            $projects[0].id | Should -Be "id1"
            $projects[1].id | Should -Be "id2"
        }

        It "persists defaultBinding correctly" {
            sf-project-get -all | % { sf-project-remove $_ }
            $proj1 = New-Object SfProject -Property @{
                id             = "idsb";
                defaultBinding = [SiteBinding]@{
                    domain   = "test";
                    port     = "55";
                    protocol = "https"
                }
            }

            _setProjectData -context $proj1

            [SfProject[]]$projects = sf-project-get -all
            $projects | Should -HaveCount 1
            $projects[0].defaultBinding.domain | Should -Be "test"
            $projects[0].defaultBinding.port | Should -Be "55"
            $projects[0].defaultBinding.protocol | Should -Be "https"
        }

        # this test is for backward compatibility when branch and site were not saved but dynamically detected
        # when they are null they are not present at all in sfdev db, meaning their value is still not known
        # being present in the db with empty value means it is known that they do not exist
        It "set branch and website to null if not present in sfdev db" {
            $date = [DateTime]::Now.AddDays(-2)
            "<?xml version=""1.0""?> `
            <data defaultTagsFilter=""t3 t4"" version=""45eaf024-ebaf-421b-9166-26018cbd0fdf""> `
              <sitefinities> `
                <sitefinity id=""sft5"" displayName=""created_from_zipaaf34aa0_48f6_44c2_89c0_3c8da6e3c3b7"" webAppPath=""C:\users\admin\Documents\sf-posh\sft5"" description="""" tags=""t3 t4"" defaultBinding=""http:created_from_zipaaf34aa0_48f6_44c2_89c0_3c8da6e3c3b7_sft5.com:2118"" /> `
                <sitefinity id=""sft1"" displayName=""created_from_zipaaf34aa0_48f6_44c2_89c0_3c8da6e3c3b7"" webAppPath=""C:\users\admin\Documents\sf-posh\sft5"" description="""" tags=""t3 t4"" defaultBinding=""http:created_from_zipaaf34aa0_48f6_44c2_89c0_3c8da6e3c3b7_sft5.com:2118"" branch="""" /> `
                <sitefinity id=""sft1"" displayName=""created_from_zipaaf34aa0_48f6_44c2_89c0_3c8da6e3c3b7"" webAppPath=""C:\users\admin\Documents\sf-posh\sft5"" description="""" tags=""t3 t4"" defaultBinding=""http:created_from_zipaaf34aa0_48f6_44c2_89c0_3c8da6e3c3b7_sft5.com:2118"" branch=""test"" /> `
                <sitefinity id=""sft1"" displayName=""created_from_zipaaf34aa0_48f6_44c2_89c0_3c8da6e3c3b7"" webAppPath=""C:\users\admin\Documents\sf-posh\sft5"" description="""" tags=""t3 t4"" lastGetLatest=""$(_serializeDate $date)"" defaultBinding=""http:created_from_zipaaf34aa0_48f6_44c2_89c0_3c8da6e3c3b7_sft5.com:2118"" branch=""test"" /> `
              </sitefinities> `
              <containers defaultContainerName="""" /> `
            </data>" | Out-File $Global:sf.config.dataPath
            [SfProject]$s = _data-getAllProjects | Select -First 1
            $null -eq $s.websiteName | Should -BeTrue
            $null -eq $s.branch | Should -BeTrue
            $null -eq $s.lastGetLatest | Should -BeTrue
            $s.daysOld | Should -Be $null
            $s = _data-getAllProjects | Select -First 1 -Skip 1
            $null -eq $s.websiteName | Should -BeTrue
            $null -eq $s.branch | Should -Not -BeTrue
            $s = _data-getAllProjects | Select -First 1 -Skip 2
            $s.branch | Should -Be "test"
            $s = _data-getAllProjects | Select -First 1 -Skip 3
            $s.lastGetLatest.ToString("dd/MM/yy HH:mm:ss") | Should -Be $date.ToString("dd/MM/yy HH:mm:ss")
            $s.daysOld | Should -Be 2
        }
    }
}
