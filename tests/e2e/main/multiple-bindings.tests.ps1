. "$PSScriptRoot\init.ps1"

InModuleScope sf-dev {
    . "$testUtilsDir\test-util.ps1"
    Describe "Test multiple bindings" {
        [SfProject]$sourceProj = Set-TestProject
        $sourceProj.defaultBinding = $null
        _setProjectData -context $sourceProj
        1..2 | % { 
            $domain = "newDomain$([System.Guid]::NewGuid().ToString()).com"
            New-WebBinding -Name $sourceProj.websiteName -HostHeader $domain -Port "55000" -Protocol 'http'
            os-hosts-add -hostname $domain -address '127.0.0.1'
        }

        $allBindings = @(iis-bindings-getAll -siteName $sourceProj.websiteName)

        [SiteBinding]$first = $allBindings | select -Last 1 -Skip 1
        [SiteBinding]$last = $allBindings | select -Last 1

        It "Default site has not been set - returns the last binding" {
            [SiteBinding]$last = $allBindings | select -Last 1
            [SiteBinding]$binding = sd-iisSite-getBinding
            $binding.domain | Should -Be $last.domain
            $binding.protocol | Should -Be $last.protocol
            $binding.port | Should -Be $last.port
        }

        It "Default site has been set - returns the binding with default site" {
            $sourceProj.defaultBinding = $first
            _setProjectData $sourceProj
            [SiteBinding]$binding = sd-iisSite-getBinding
            $binding.domain | Should -Be $first.domain
            $binding.protocol | Should -Be $first.protocol
            $binding.port | Should -Be $first.port
        }

        It "Default site has been set, but binding was deleted - returns the last binding" {
            Remove-WebBinding -Name $sourceProj.websiteName -Protocol $first.protocol -Port $first.port -HostHeader $first.domain
            [SiteBinding]$binding = sd-iisSite-getBinding
            $binding.domain | Should -Be $last.domain
            $binding.protocol | Should -Be $last.protocol
            $binding.port | Should -Be $last.port
            New-WebBinding -Name $sourceProj.websiteName -Protocol $first.protocol -Port $first.port -HostHeader $first.domain
            New-WebBinding -Name $sourceProj.websiteName -Protocol 'http' -Port '55534' -HostHeader 'dummylast'
            [SiteBinding]$binding = sd-iisSite-getBinding
            $binding.domain | Should -Be $first.domain
            $binding.protocol | Should -Be $first.protocol
            $binding.port | Should -Be $first.port
            Remove-WebBinding -Name $sourceProj.websiteName -Protocol 'http' -Port '55534' -HostHeader 'dummylast'
        }

        It "Changing the binding removes the hosts file entry and adds a new one, also changes the domain of the current binding. If it is configured as default also changes the default binding." {
            [SiteBinding]$binding = sd-iisSite-getBinding
            $result = os-hosts-get | ? { $_.Contains($binding.domain) }
            $result | Should -Not -BeNullOrEmpty
            $domain = "newDomain$([System.Guid]::NewGuid().ToString()).com"
            sd-iisSite-changeDomain -domainName $domain
            [SiteBinding]$newBinding = sd-iisSite-getBinding
            $newBinding.domain | Should -Be $domain
            [SiteBinding[]]$newAllBindings = iis-bindings-getAll -siteName $sourceProj.websiteName
            $result = $newAllBindings | ? { $_.domain -eq $binding.domain } 
            $result | Should -BeNullOrEmpty
            $result = $newAllBindings | ? { $_.domain -eq $newBinding.domain } 
            $result | Should -Not -BeNullOrEmpty
            $result = os-hosts-get | ? { $_.Contains($binding.domain) }
            $result | Should -BeNullOrEmpty
            $result = os-hosts-get | ? { $_.Contains($newBinding.domain) }
            $result | Should -Not -BeNullOrEmpty
        }
    }
}