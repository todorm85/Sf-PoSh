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
    Describe "Nlb new cluster should" {
        Mock sf-app-sendRequestAndEnsureInitialized { }
        InTestProjectScope {
            It "create a second project" {
                [SfProject]$script:firstNode = sf-project-getCurrent
                sf-nlb-newCluster
                $script:secondNode = sf-project-getAll | ? id -ne $firstNode.id
                $secondNode | Should -HaveCount 1
            }

            It "both projects should use same db" {
                sf-db-getNameFromDataConfig -context $firstNode | Should -Not -BeNullOrEmpty
                sf-db-getNameFromDataConfig -context $firstNode | Should -Be (sf-db-getNameFromDataConfig -context $secondNode)
            }

            It "set same nlb id for both projects" {
                $nlbId = sf-nlbData-getNlbIds -projectId $firstNode.id
                $nlbId | Should -HaveCount 1
                sf-nlbData-getNlbIds -projectId $secondNode.id | Should -Be $nlbId
            }

            It "configure nlb nodes in system config for both nodes" {
                [SiteBinding]$firstNodeBinding = sf-bindings-getLocalhostBinding -websiteName $firstNode.websiteName
                [SiteBinding]$secondNodeBinding = sf-bindings-getLocalhostBinding -websiteName $secondNode.websiteName
                $firstNodeUrl = "$($firstNodeBinding.protocol)://localhost:$($firstNodeBinding.port)"
                $secondNodeUrl = "$($secondNodeBinding.protocol)://localhost:$($secondNodeBinding.port)"
                $fnConf = "$($script:firstNode.webAppPath)\App_Data\Sitefinity\Configuration\SystemConfig.config"
                $snConf = "$($script:secondNode.webAppPath)\App_Data\Sitefinity\Configuration\SystemConfig.config"
                [xml]$config = Get-Content $fnConf
                $params = $config.systemConfig.loadBalancingConfig.parameters.add
                $params | Should -HaveCount 2
                $params[0].GetAttribute("value") | Should -BeLike "*$firstNodeUrl*"
                $params[1].GetAttribute("value") | Should -BeLike "*$secondNodeUrl*"
                $config.systemConfig.sslOffloadingSettings.GetAttribute("EnableSslOffloading") | Should -be "True"
                [xml]$config = Get-Content $snConf
                $params = $config.systemConfig.loadBalancingConfig.parameters.add
                $params | Should -HaveCount 2
                $params[0].GetAttribute("value") | Should -BeLike "*$firstNodeUrl*"
                $params[1].GetAttribute("value") | Should -BeLike "*$secondNodeUrl*"
                $config.systemConfig.sslOffloadingSettings.GetAttribute("EnableSslOffloading") | Should -be "True"
            }
        }
    }
}