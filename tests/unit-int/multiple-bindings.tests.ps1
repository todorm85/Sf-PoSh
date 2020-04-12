. "${PSScriptRoot}\load.ps1"

InModuleScope sf-dev {
    . "$PSScriptRoot\init.ps1"

    Describe "Test multiple bindings" {
        . "$PSScriptRoot\test-project-init.ps1"
        [SfProject]$sourceProj = sf-project-getCurrent

        It "Default site has not been set - returns the last binding" {
            1..2 | % {
                $domain = "sfi$([System.Guid]::NewGuid().ToString()).com"
                $port = sf-getFreePort
                New-WebBinding -Name $sourceProj.websiteName -HostHeader $domain -Port $port -Protocol 'http'
                os-hosts-add -hostname $domain
            }

            $allBindings = @(iis-bindings-getAll -siteName $sourceProj.websiteName)
            [SiteBinding]$last = $allBindings | select -Last 1
            $sourceProj.defaultBinding | Should -BeNullOrEmpty
            [SiteBinding]$binding = sf-iisSite-getBinding
            $binding.domain | Should -Be $last.domain
            $binding.protocol | Should -Be $last.protocol
            $binding.port | Should -Be $last.port
        }

        It "Default site has been set - returns the binding with default site" {
            $allBindings = @(iis-bindings-getAll -siteName $sourceProj.websiteName)
            [SiteBinding]$beforeLast = $allBindings | select -Last 1 -Skip 1
            $sourceProj.defaultBinding = $beforeLast
            sf-project-save $sourceProj
            [SiteBinding]$binding = sf-iisSite-getBinding
            $binding.domain | Should -Be $beforeLast.domain
            $binding.protocol | Should -Be $beforeLast.protocol
            $binding.port | Should -Be $beforeLast.port
        }

        It "Default binding has been set, but binding was deleted from site or hosts file - returns the last binding" {
            # set the default binding to be before last
            $allBindings = @(iis-bindings-getAll -siteName $sourceProj.websiteName)
            [SiteBinding]$beforeLast = $allBindings | select -Last 1 -Skip 1
            [SiteBinding]$last = $allBindings | select -Last 1
            $sourceProj.defaultBinding = $beforeLast
            sf-project-save $sourceProj

            # remove the default binding from website
            Remove-WebBinding -Name $sourceProj.websiteName -Protocol $beforeLast.protocol -Port $beforeLast.port -HostHeader $beforeLast.domain

            # check last binding is returned
            [SiteBinding]$binding = sf-iisSite-getBinding
            $binding.domain | Should -Be $last.domain
            $binding.protocol | Should -Be $last.protocol
            $binding.port | Should -Be $last.port

            #restore the default binding
            New-WebBinding -Name $sourceProj.websiteName -Protocol $beforeLast.protocol -Port $beforeLast.port -HostHeader $beforeLast.domain
            Mock _promptBindings { $beforeLast }
            sf-iisSite-setBinding

            # remove the default bindingdomain from hosts
            os-hosts-remove -hostname $beforeLast.domain

            # check last binding is returned
            [SiteBinding]$binding = sf-iisSite-getBinding
            [SiteBinding]$last = @(iis-bindings-getAll -siteName $sourceProj.websiteName) | select -Last 1
            $binding.domain | Should -Be $last.domain
            $binding.protocol | Should -Be $last.protocol
            $binding.port | Should -Be $last.port

            #restore the default binding
            os-hosts-add -hostname $beforeLast.domain
            Mock _promptBindings { $beforeLast }
            sf-iisSite-setBinding
        }

        It "Changing the binding removes the hosts file entry and adds a new one, also changes the domain of the current binding." {
            [SiteBinding]$binding = sf-iisSite-getBinding
            $oldDomain = $binding.domain
            $result = os-hosts-get | ? { $_.Contains($binding.domain) }
            $result | Should -Not -BeNullOrEmpty
            $domain = "sfi$([System.Guid]::NewGuid().ToString()).com"
            sf-iisSite-changeDomain -domainName $domain
            [SiteBinding]$newBinding = sf-iisSite-getBinding
            $newBinding.domain | Should -Be $domain
            [SiteBinding[]]$newAllBindings = iis-bindings-getAll -siteName $sourceProj.websiteName
            $result = $newAllBindings | ? { $_.domain -eq $oldDomain }
            $result | Should -BeNullOrEmpty
            $result = $newAllBindings | ? { $_.domain -eq $newBinding.domain }
            $result | Should -Not -BeNullOrEmpty
            $result = os-hosts-get | ? { $_.Contains($oldDomain) }
            $result | Should -BeNullOrEmpty
            $result = os-hosts-get | ? { $_.Contains($newBinding.domain) }
            $result | Should -Not -BeNullOrEmpty
        }

        It "changing domain for a default binding updates the default binding as well" {
            $port = sf-getFreePort
            $domain = "sfi$([GUID]::NewGuid().ToString()).com"
            os-hosts-add -hostname $domain
            [SiteBinding]$binding = @{ protocol = 'http'; domain = $domain; port = $port }
            Mock _promptBindings { $binding }
            sf-iisSite-setBinding

            $defBinding = (sf-project-getCurrent).defaultBinding
            $defBinding.domain | Should -Be $binding.domain
            $defBinding.protocol | Should -Be $binding.protocol
            $defBinding.port | Should -Be $binding.port

            $domain = "sfi$([GUID]::NewGuid().ToString()).com"
            sf-iisSite-changeDomain -domainName $domain
            $p = sf-project-getCurrent

            $p.defaultBinding.domain | Should -Be $domain
            $p.defaultBinding.protocol | Should -Be $binding.protocol
            $p.defaultBinding.port | Should -Be $binding.port
        }

        It "selecting a project with invalid default binding clears it from the project and prompts the user to select a new default binding" {
            # set the default binding to be before last
            $allBindings = @(iis-bindings-getAll -siteName $sourceProj.websiteName)
            [SiteBinding]$beforeLast = $allBindings | select -Last 1 -Skip 1
            [SiteBinding]$last = $allBindings | select -Last 1
            $sourceProj.defaultBinding = $beforeLast
            sf-project-save $sourceProj

            # remove the default binding from website
            Remove-WebBinding -Name $sourceProj.websiteName -Protocol $beforeLast.protocol -Port $beforeLast.port -HostHeader $beforeLast.domain

            # check user prompted for binding and default binding is removed from sfdev project
            $project = sf-project-getCurrent
            $project.defaultBinding | Should -Not -BeNullOrEmpty
            Mock _promptProjectSelect { $project }
            Mock Read-Host { 'n' }
            sf-project-select
            $project = sf-project-getCurrent
            $project.defaultBinding | Should -BeNullOrEmpty
        }

        It "adds a hosts entry if missing when setting a new default binding" {
            $binding = sf-iisSite-getBinding
            $binding | Should -Not -BeNullOrEmpty
            os-hosts-remove -hostname $binding.domain
            Mock _promptBindings { $binding }
            $binding = sf-iisSite-setBinding
            os-hosts-get | % { $_.Contains($binding.domain)} | select -First 1 | Should -Not -BeNullOrEmpty
        }

        . "$PSScriptRoot\test-project-teardown.ps1"
    }
}