. "$PSScriptRoot\load.ps1"
InModuleScope sf-posh {
    Describe "Common config ops should" {
        InTestProjectScope {
            It "Create the config when not created with proper version" {
                [xml]$xml = sf-config-open "dedov"
                $xml.dedovConfig.version | Should -Be "13.0.7300.0"
            }
            It "Get the existing config when created" {
                [xml]$xml = sf-config-open "dedov"
                $xml.dedovConfig.GetAttribute("dummy") | Should -Not -Be "opa"
                $xml.dedovConfig.SetAttribute("dummy", "opa")
                sf-config-save -config $xml
                [xml]$xml = sf-config-open "dedov"
                $xml.dedovConfig.GetAttribute("dummy") | Should -Be "opa"
            }
            It "create elemet when not existing and get element if exists" {
                [xml]$xml = sf-config-open "dedov"
                $testEl = xml-getOrCreateElementPath $xml.dedovConfig test
                $testEl.SetAttribute("testAt", "opa")
                $testEl.SetAttribute("testB", "opaB")
                sf-config-save $xml
                [xml]$xml = sf-config-open "dedov"
                $xml.dedovConfig.test.GetAttribute("testAt") | Should -be "opa"

                $testEl = xml-getOrCreateElementPath $xml.dedovConfig "test[@testAt='opa']"
                $testEl.GetAttribute("testB") | Should -be "opaB"
            }
            It "create elemet path when not existing and get element if exists" {
                [xml]$xml = sf-config-open "dedov"
                $testEl = xml-getOrCreateElementPath $xml.dedovConfig "test/testChild/testGrandChild"
                $testEl.SetAttribute("testAt", "grandChildVal")
                sf-config-save $xml
                [xml]$xml = sf-config-open "dedov"
                $xml.dedovConfig.test.testChild.testGrandChild.GetAttribute("testAt") | Should -be "grandChildVal"
                $testEl = xml-getOrCreateElementPath $xml.dedovConfig "test/testChild"
                $testEl.SetAttribute("testAt", "testChildVal")
                sf-config-save $xml
                [xml]$xml = sf-config-open "dedov"
                $xml.dedovConfig.test.testChild.GetAttribute("testAt") | Should -be "testChildVal"
            }
        }
    }

    Describe "System config ops should" {
        InTestProjectScope {
            It "Set ssl offloading correctly" {
                $conf = sf-config-open "System"
                $conf.systemConfig.sslOffloadingSettings | Should -BeNullOrEmpty
                sf-config-System-setSslOffload $true
                $conf = sf-config-open "System"
                $conf.systemConfig.sslOffloadingSettings.GetAttribute("EnableSslOffloading") | Should -Be "True"
                sf-config-System-setSslOffload $false
                $conf = sf-config-open "System"
                $conf.systemConfig.sslOffloadingSettings.GetAttribute("EnableSslOffloading") | Should -Be "False"
            }

            It "Set nlb nodes correctly and not destroy other config settings" {
                $conf = sf-config-open "System"
                $conf.systemConfig.loadBalancingConfig | Should -BeNullOrEmpty
                sf-config-System-setNlbUrls @("uno", "dos", "tr")
                $conf = sf-config-open "System"
                $entries = $conf.systemConfig.loadBalancingConfig.parameters.add
                $entries | Should -HaveCount 3
                $entries[0].GetAttribute("value") | Should -Be "uno"
                $entries[1].GetAttribute("value") | Should -Be "dos"
                $entries[2].GetAttribute("value") | Should -Be "tr"
                $conf.systemConfig.sslOffloadingSettings | Should -Not -BeNullOrEmpty
            }

            It "Clear nlb nodes then add new nodes correctly" {
                $conf = sf-config-open "System"
                $conf.systemConfig.loadBalancingConfig.parameters.add | Should -HaveCount 3
                sf-config-System-setNlbUrls
                $conf = sf-config-open "System"
                $entries = @($conf.systemConfig.loadBalancingConfig.parameters.add)
                $entries | Should -BeNullOrEmpty
                $conf.systemConfig.sslOffloadingSettings | Should -Not -BeNullOrEmpty
                sf-config-System-setNlbUrls @("uno")
                $conf = sf-config-open "System"
                $entries = @($conf.systemConfig.loadBalancingConfig.parameters.add)
                $entries | Should -HaveCount 1
                $entries[0].GetAttribute("value") | Should -Be "uno"
            }
        }
    }

    Describe "Web config ops should" {
        InTestProjectScope {
            It "Set machine key correctly" {
                [SfProject]$Script:p = sf-project-get
                $webConfigRaw = Get-Content "$($p.webAppPath)\web.config" -Raw
                $webConfigRaw | Should -Not -BeNullOrEmpty
                $webConfigRaw -match "machineKey" | Should -BeFalse
                sf-config-Web-setMachineKey
                $webConfigRaw = Get-Content "$($p.webAppPath)\web.config" -Raw
                $webConfigRaw -match "machineKey" | Should -BeTrue
            }
            It "Remove machine key correctly" {
                sf-config-Web-removeMachineKey
                $webConfigRaw = Get-Content "$($p.webAppPath)\web.config" -Raw
                $webConfigRaw | Should -Not -BeNullOrEmpty
                $webConfigRaw -match "machineKey" | Should -BeFalse
            }
            It "Remove machine do nothing when no machine key" {
                sf-config-Web-removeMachineKey
                $webConfigRaw = Get-Content "$($p.webAppPath)\web.config" -Raw
                $webConfigRaw | Should -Not -BeNullOrEmpty
                $webConfigRaw -match "machineKey" | Should -BeFalse
            }
        }
    }
}