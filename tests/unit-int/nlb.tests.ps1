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
                $result = _nlbData-get
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
                $result = _nlbData-get
                $result | Should -HaveCount 1
                $result[0].NlbId | Should -Be "nlb1"
                $result[0].ProjectId | Should -Be "project1"
            }
            It "persist zero object" {
                $d = @()
                _nlbData-set -data $d
                $result = _nlbData-get
                $result | Should -BeNullOrEmpty
            }
            It "add one object" {
                $e = [NlbEntity]@{
                    NlbId     = "nlb1";
                    ProjectId = "project1"
                }

                _nlbData-add -entry $e
                $res = _nlbData-get
                $res | Should -HaveCount 1
            }
            It "add duplicate object do nothing" {
                $e = [NlbEntity]@{
                    NlbId     = "nlb1";
                    ProjectId = "project1"
                }

                _nlbData-add -entry $e
                _nlbData-get | ? { $_ -eq $e } | Should -HaveCount 1
            }
            It "remove one object when only one" {
                $e = [NlbEntity]@{
                    NlbId     = "nlb1";
                    ProjectId = "project1"
                }

                _nlbData-remove -entry $e
                _nlbData-get | ? { $_ -eq $e } | Should -BeNullOrEmpty
            }
            It "remove one object when many" {
                for ($i = 0; $i -lt 5; $i++) {
                    $e = [NlbEntity]@{
                        NlbId     = "nlb$i";
                        ProjectId = "project$i"
                    }
                    
                    _nlbData-add $e
                }

                $e = [NlbEntity]@{
                    NlbId     = "nlb2";
                    ProjectId = "project2"
                }

                _nlbData-remove $e
                _nlbData-get | Should -Not -Contain $e
                _nlbData-get | Should -HaveCount 4
                (_nlbData-get)[0] | Should -Be ([NlbEntity]@{ NlbId = "nlb0"; ProjectId = "project0" })
                (_nlbData-get)[1] | Should -Be ([NlbEntity]@{ NlbId = "nlb1"; ProjectId = "project1" })
                (_nlbData-get)[2] | Should -Be ([NlbEntity]@{ NlbId = "nlb3"; ProjectId = "project3" })
                (_nlbData-get)[3] | Should -Be ([NlbEntity]@{ NlbId = "nlb4"; ProjectId = "project4" })
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
                $ids = _nlbData-getProjectIds -nlbId "nlb1"
                $ids | Should -HaveCount 2
                $ids | Should -Contain "project1"
                $ids | Should -Contain "project3"
            }
            It "get projectIds get none when wrong id" {
                $ids = _nlbData-getProjectIds -nlbId "sdfsdf"
                $ids | Should -BeNullOrEmpty
            }
            It "get nlbIds get when many entries" {
                _nlbData-getNlbIds -projectId "project2" | Should -Be "nlb2"
                _nlbData-getNlbIds -projectId "project1" | Should -Be "nlb1"
                _nlbData-getNlbIds -projectId "project3" | Should -Be "nlb1"
                $newE = [NlbEntity]@{
                    NlbId     = "nlb3";
                    ProjectId = "project2"
                }

                _nlbData-add  -entry $newE
                _nlbData-getNlbIds -projectId "project2" | Should -Be @("nlb2", "nlb3")
            }
        }
    }
    
    Describe "Nlb cluster ops should" {
        Mock sf-app-ensureRunning { }
        InTestProjectScope {
            It "create a second project" {
                [SfProject]$script:firstNode = sf-PSproject-get
                sf-nlb-newCluster
                [SfProject]$script:secondNode = sf-PSproject-get -all | ? id -ne $firstNode.id
                $secondNode | Should -HaveCount 1
                Get-Website | ? name -eq $secondNode.websiteName | Should -Not -BeNullOrEmpty
                Get-Item "IIS:\AppPools\$($secondNode.id)" | Should -Not -BeNullOrEmpty
                Test-Path $secondNode.webAppPath | Should -BeTrue
            }

            It "both projects should use same db" {
                sf-db-getNameFromDataConfig -context $firstNode | Should -Not -BeNullOrEmpty
                sf-db-getNameFromDataConfig -context $firstNode | Should -Be (sf-db-getNameFromDataConfig -context $secondNode)
            }

            It "set same nlb id for both projects" {
                $script:nlbId = $firstNode.nlbId
                $nlbId | Should -HaveCount 1
                $secondNode.nlbId | Should -Be $nlbId
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

            It "add Nlb mapping for projects" {
                _nlbData-get | ? { $_.ProjectId -eq $firstNode.id } | Should -HaveCount 1
                _nlbData-get | ? { $_.ProjectId -eq $secondNode.id } | Should -HaveCount 1
                _nlbData-get | ? { $_.NlbId -eq $nlbId } | Should -HaveCount 2
            }

            It "add entry to hosts file" {
                os-hosts-get | ? { $_ -like "*$nlbId*" } | Should -Not -BeNullOrEmpty
            }

            It "create the nginx config" { 
                $path = _nginx-getClusterConfigPath $nlbId
                Test-Path $path | Should -BeTrue
                Get-Content $path | ? { $_ -like "*$nlbId.sfdev.com*" } | Should -Not -BeNullOrEmpty
            }

            It "change name in config when renaming the cluster" { 
                $path = _nginx-getClusterConfigPath $nlbId
                sf-nlb-changeUrl -hostname "newname.com"
                Get-Content $path | ? { $_ -like "*newname.com*" } | Should -Not -BeNullOrEmpty
            }

            It "remove old entry from hosts file after rename and add new" {
                os-hosts-get | ? { $_ -like "*$nlbId*" } | Should -BeNullOrEmpty
                os-hosts-get | ? { $_ -like "*newname*" } | Should -Not -BeNullOrEmpty
            }

            It "remove other project when removing cluster" {
                sf-PSproject-setCurrent $firstNode
                sf-nlb-removeCluster
                sf-PSproject-get -all | ? id -eq $secondNode.id | Should -BeNullOrEmpty
                Get-Website | ? name -eq $secondNode.websiteName | Should -BeNullOrEmpty
                Test-Path "IIS:\AppPools\$($secondNode.id)" | Should -BeFalse
                Test-Path $secondNode.webAppPath | Should -BeFalse
                sql-get-dbs | ? name -eq (sf-db-getNameFromDataConfig) | Should -HaveCount 1
            }

            It "undo settings in systemConfig" { 
                $fnConf = "$($script:firstNode.webAppPath)\App_Data\Sitefinity\Configuration\SystemConfig.config"
                [xml]$config = Get-Content $fnConf
                $params = $config.systemConfig.loadBalancingConfig.parameters.add
                $params | Should -BeNullOrEmpty
                $config.systemConfig.sslOffloadingSettings.GetAttribute("EnableSslOffloading") | Should -be "False"
            }

            It "removes nlb mapping" {
                _nlbData-get | ? { $_.ProjectId -eq $firstNode.id } | Should -BeNullOrEmpty
                _nlbData-get | ? { $_.ProjectId -eq $secondNode.id } | Should -BeNullOrEmpty
                _nlbData-get | ? { $_.NlbId -eq $nlbId } | Should -BeNullOrEmpty
            }

            It "remove the nginx config" { 
                $path = _nginx-getClusterConfigPath $nlbId
                Test-Path $path | Should -BeFalse
            }

            It "remove the domain from hosts file" {
                os-hosts-get | ? { $_ -like "*newname*" } | Should -BeNullOrEmpty
            }
        }
    }

    Describe "removing one porject should" {
        Mock sf-app-ensureRunning { }
        InTestProjectScope {
            It "Remove nlb cluster config" {
                [SfProject]$script:firstNode = sf-PSproject-get
                sf-nlb-newCluster
                [SfProject]$script:secondNode = sf-PSproject-get -all | ? id -ne $firstNode.id
                $secondNode | Should -HaveCount 1
                Get-Website | ? name -eq $secondNode.websiteName | Should -Not -BeNullOrEmpty
                Get-Item "IIS:\AppPools\$($secondNode.id)" | Should -Not -BeNullOrEmpty
                Test-Path $secondNode.webAppPath | Should -BeTrue
                $script:nlbId = $firstNode.nlbId
                sf-PSproject-remove -project $secondNode -noPrompt
            }

            It "do not remove other node" {
                [SfProject]$p = sf-PSproject-get -all | ? id -eq $script:firstNode.id
                $p | Should -HaveCount 1
            }
                
            It "undo settings in systemConfig" { 
                $fnConf = "$($script:firstNode.webAppPath)\App_Data\Sitefinity\Configuration\SystemConfig.config"
                [xml]$config = Get-Content $fnConf
                $params = $config.systemConfig.loadBalancingConfig.parameters.add
                $params | Should -BeNullOrEmpty
                $config.systemConfig.sslOffloadingSettings.GetAttribute("EnableSslOffloading") | Should -be "False"
            }

            It "removes nlb mapping" {
                _nlbData-get | ? { $_.ProjectId -eq $firstNode.id } | Should -BeNullOrEmpty
                _nlbData-get | ? { $_.ProjectId -eq $secondNode.id } | Should -BeNullOrEmpty
                _nlbData-get | ? { $_.NlbId -eq $nlbId } | Should -BeNullOrEmpty
                $firstNode.nlbId | Should -BeNullOrEmpty
            }

            It "remove the nginx config" { 
                $path = _nginx-getClusterConfigPath $nlbId
                Test-Path $path | Should -BeFalse
            }

            It "remove the domain from hosts file" {
                os-hosts-get | ? { $_ -like "*newname*" } | Should -BeNullOrEmpty
            }
        }
    }
}