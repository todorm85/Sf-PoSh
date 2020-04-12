function sf-iisSite-getBinding {
    [SfProject]$context = sf-project-getCurrent
    if (!$context) {
        throw "No project selected."
    }

    if (!$context.websiteName) {
        Write-Warning "No website for current project."
        return
    }

    if ($context.defaultBinding -and (_checkDefaultBindingIsWorking)) {
        return $context.defaultBinding
    }
    
    $allBindings = iis-bindings-getAll -siteName $context.websiteName
    $binding = $allBindings | Select-Object -Last 1

    return $binding
}

function sf-iisSite-setBinding {
    [SfProject]$project = sf-project-getCurrent
    $selectedBinding = _promptBindings
    $project.defaultBinding = [SiteBinding]$defBinding = @{
        protocol = $selectedBinding.protocol
        domain   = $selectedBinding.domain
        port     = $selectedBinding.port
    }

    if ($binding.domain -and !(os-hosts-get | % { $_.Contains($binding.domain)})) {
        os-hosts-add -hostname $binding.domain
    }

    sf-project-save -context $project
}

function sf-iisSite-getUrl {
    [SiteBinding]$binding = sf-iisSite-getBinding
    _sd-iisSite-buildUrlFromBinding -binding $binding
}

function _sd-iisSite-buildUrlFromBinding ([SiteBinding]$binding) {
    $hostname = if ($binding.domain) {$binding.domain} else {"localhost"}
    return _iisSite-appendSubAppPath "$($binding.protocol)://$($hostname):$($binding.port)"
}

function sf-iisSite-changeDomain {
    param (
        $domainName
    )

    [SiteBinding]$binding = sf-iisSite-getBinding
    if ($binding) {
        [SfProject]$p = sf-project-getCurrent
        $websiteName = $p.websiteName
        try {
            Remove-WebBinding -Name $websiteName -Port $binding.port -HostHeader $binding.domain -Protocol $binding.protocol
            os-hosts-remove -hostname $binding.domain > $null
        }
        catch {
            Write-Warning "Error cleaning previous domain. $_"
        }

        New-WebBinding -Name $websiteName -Protocol $binding.protocol -Port $binding.port -HostHeader $domainName
        os-hosts-add -address 127.0.0.1 -hostname $domainName

        if ($p.defaultBinding) {
            $p.defaultBinding.domain = $domainName
            sf-project-save -context $p
        }
    }
    else {
        Write-Warning "No binding found for site $websiteName"
    }
}

function _iisSite-appendSubAppPath {
    param($path)

    $context = sf-project-getCurrent
    $subAppName = sf-iisSite-getSubAppName -websiteName $context.websiteName
    if ($null -ne $subAppName) {
        $path = "$path/${subAppName}"
    }

    return $path
}

function _generateDomainName {
    Param(
        [Parameter(Mandatory = $true)]
        [SfProject]
        $context
    )

    return "$($context.displayName)_$($context.id).com"
}

function _promptBindings {
    [SfProject]$project = sf-project-getCurrent
    [SiteBinding[]]$bindings = iis-bindings-getAll -siteName $project.websiteName
    if (!$bindings) {
        Write-Warning "No bindings defined for website."
        return
    }

    $i = 0
    $bindings | % {
        $domain = if ($_.domain) { $_.domain } else { 'localhost' }
        Write-Host "$i : $($_.protocol)://$($domain):$($_.port)"
        $i++
    }

    while ($true) {
        $choice = Read-Host -Prompt "Choose default binding:"
        $index = $null
        if (!([int]::TryParse($choice, [ref]$index))) { return }
        $selectedBinding = $bindings[$index]
        if ($selectedBinding) {
            return $selectedBinding
        }
    }
}

function _verifyDefaultBinding {
    $selectedSitefinity = sf-project-getCurrent
    if (!$selectedSitefinity.websiteName) { return }
    [SiteBinding[]]$bindings = iis-bindings-getAll -siteName $selectedSitefinity.websiteName
    if (!$selectedSitefinity.defaultBinding -and $bindings -and $bindings.Count -gt 1) {
        $choice = Read-Host -Prompt "Site has several bindings and there is no default one set. Do you want to set a default binding to be used by the tool? y/n"
        if ($choice -eq 'y') {
            sf-iisSite-setBinding
        }
    }
    elseif ($selectedSitefinity.defaultBinding -and !(_checkDefaultBindingIsWorking)) {
        $selectedSitefinity.defaultBinding = $null
        sf-project-save $selectedSitefinity
        _verifyDefaultBinding
    }
}

function _checkDefaultBindingIsWorking {
    $selectedSitefinity = sf-project-getCurrent
    $allBindings = iis-bindings-getAll -siteName $selectedSitefinity.websiteName
    $binding = $allBindings | Where-Object { $_.domain -eq $selectedSitefinity.defaultBinding.domain -and $_.protocol -eq $selectedSitefinity.defaultBinding.protocol -and $_.port -eq $selectedSitefinity.defaultBinding.port }
    if (!(os-hosts-get | ? { $_.Contains($selectedSitefinity.defaultBinding.domain) })) {
        $binding = $null
    }

    return $binding
}