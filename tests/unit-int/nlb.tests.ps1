. "$PSScriptRoot\load.ps1"
InModuleScope sf-posh {
    Describe "Nlb data should" {
        InTestProjectScope {
            It "persist objects" {
                $d = @(
                    [NlbEntity]@{
                        NlbId     = "nlb1";
                        ProjectId = "project1"
                    },
                    [NlbEntity]@{
                        NlbId     = "nlb2";
                        ProjectId = "project2"
                    },
                    [NlbEntity]@{
                        NlbId     = "nlb3";
                        ProjectId = "project3"
                    }
                )

                _nlbData-set -data $d
                $result = sf-nlbData-get
                $result | Should -HaveCount 3
                $result[0].NlbId | Should -Be "nlb1"
                $result[0].ProjectId | Should -Be "project1"
                $result[1].NlbId | Should -Be "nlb2"
                $result[1].ProjectId | Should -Be "project2"
                $result[2].NlbId | Should -Be "nlb3"
                $result[2].ProjectId | Should -Be "project3"
            }
            It "persist one object" { 
                $d = @(
                    [NlbEntity]@{
                        NlbId     = "nlb1";
                        ProjectId = "project1"
                    }
                )
                
                _nlbData-set -data $d
                $result = sf-nlbData-get
                $result | Should -HaveCount 1
                $result[0].NlbId | Should -Be "nlb1"
                $result[0].ProjectId | Should -Be "project1"
            }
            It "persist zero object" {
                $d = @()
                _nlbData-set -data $d
                $result = sf-nlbData-get
                $result | Should -BeNullOrEmpty
            }
            It "add one object" {
                $e = [NlbEntity]@{
                    NlbId     = "nlb1";
                    ProjectId = "project1"
                }

                sf-nlbData-add -entry $e
                $res = sf-nlbData-get
                $res | Should -HaveCount 1
            }
            It "add duplicate object do nothing" {
                $e = [NlbEntity]@{
                    NlbId     = "nlb1";
                    ProjectId = "project1"
                }

                sf-nlbData-add -entry $e
                sf-nlbData-get | ? { $_ -eq $e } | Should -HaveCount 1
            }
            It "remove one object when only one" {
                $e = [NlbEntity]@{
                    NlbId     = "nlb1";
                    ProjectId = "project1"
                }

                sf-nlbData-remove -entry $e
                sf-nlbData-get | ? { $_ -eq $e } | Should -BeNullOrEmpty
            }
            It "remove one object when many" {
                for ($i = 0; $i -lt 5; $i++) {
                    $e = [NlbEntity]@{
                        NlbId     = "nlb$i";
                        ProjectId = "project$i"
                    }
                    
                    sf-nlbData-add $e
                }

                $e = [NlbEntity]@{
                    NlbId     = "nlb2";
                    ProjectId = "project2"
                }

                sf-nlbData-remove $e
                sf-nlbData-get | Should -Not -Contain $e
                sf-nlbData-get | Should -HaveCount 4
                (sf-nlbData-get)[0] | Should -Be ([NlbEntity]@{ NlbId = "nlb0"; ProjectId = "project0" })
                (sf-nlbData-get)[1] | Should -Be ([NlbEntity]@{ NlbId = "nlb1"; ProjectId = "project1" })
                (sf-nlbData-get)[2] | Should -Be ([NlbEntity]@{ NlbId = "nlb3"; ProjectId = "project3" })
                (sf-nlbData-get)[3] | Should -Be ([NlbEntity]@{ NlbId = "nlb4"; ProjectId = "project4" })
            }
            It "get projectIds when many" {
                $d = @(
                    [NlbEntity]@{
                        NlbId     = "nlb1";
                        ProjectId = "project1"
                    },
                    [NlbEntity]@{
                        NlbId     = "nlb2";
                        ProjectId = "project2"
                    },
                    [NlbEntity]@{
                        NlbId     = "nlb1";
                        ProjectId = "project3"
                    }
                )

                _nlbData-set -data $d
                $ids = sf-nlbData-getProjectIds -nlbId "nlb1"
                $ids | Should -HaveCount 2
                $ids | Should -Contain "project1"
                $ids | Should -Contain "project3"
            }
            It "get projectIds get none when wrong id" {
                $ids = sf-nlbData-getProjectIds -nlbId "sdfsdf"
                $ids | Should -BeNullOrEmpty
            }
            It "get nlbIds get when many entries" {
                sf-nlbData-getNlbIds -projectId "project2" | Should -Be "nlb2"
                sf-nlbData-getNlbIds -projectId "project1" | Should -Be "nlb1"
                sf-nlbData-getNlbIds -projectId "project3" | Should -Be "nlb1"
                $newE = [NlbEntity]@{
                    NlbId     = "nlb3";
                    ProjectId = "project2"
                }

                sf-nlbData-add  -entry $newE
                sf-nlbData-getNlbIds -projectId "project2" | Should -Be @("nlb2","nlb3")
            }
        }
    }
}