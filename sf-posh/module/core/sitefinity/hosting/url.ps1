function sf-iis-site-getBinding {
    [SfProject]$context = sf-PSproject-get
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

function sf-iis-site-setBinding {
    Param(
        [SiteBinding]$defBinding
    )

    [SfProject]$project = sf-PSproject-get
    if (!$defBinding) {
        $selectedBinding = _promptBindings
        $defBinding = @{
            protocol = $selectedBinding.protocol
            domain   = $selectedBinding.domain
            port     = $selectedBinding.port
        }
    }

    $project.defaultBinding = $defBinding

    if ($binding.domain -and !(os-hosts-get | % { $_.Contains($binding.domain) })) {
        os-hosts-add -hostname $binding.domain
    }

    sf-PSproject-save -context $project
}

function sf-iis-site-getUrl {
    [SiteBinding]$binding = sf-iis-site-getBinding
    _sd-iisSite-buildUrlFromBinding -binding $binding
}

function _sd-iisSite-buildUrlFromBinding ([SiteBinding]$binding) {
    $hostname = if ($binding.domain) { $binding.domain } else { "localhost" }
    return _iisSite-appendSubAppPath "$($binding.protocol)://$($hostname):$($binding.port)"
}

function sf-iis-site-changeDomain {
    param (
        $domainName
    )

    [SiteBinding]$binding = sf-iis-site-getBinding
    if ($binding) {
        [SfProject]$p = sf-PSproject-get
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
            sf-PSproject-save -context $p
        }
    }
    else {
        Write-Warning "No binding found for site $websiteName"
    }
}

function _iisSite-appendSubAppPath {
    param($path)

    $context = sf-PSproject-get
    $subAppName = sf-iis-site-getSubAppName -websiteName $context.websiteName
    if ($null -ne $subAppName) {
        $path = "$path/${subAppName}"
    }

    return $path
}

function _promptBindings {
    [SfProject]$project = sf-PSproject-get
    if (!$project.websiteName) {
        Write-Warning "No website for project."
        return
    }

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

function _checkAndUpdateBindings {
    param([SfProject]$selectedSitefinity)
    if (!$selectedSitefinity.websiteName) { return }
    if (!$selectedSitefinity.defaultBinding) {
        [SiteBinding[]]$bindings = iis-bindings-getAll -siteName $selectedSitefinity.websiteName
        # if ($bindings.Count -gt 2) {
        #     $choice = Read-Host -Prompt "Site has several bindings and there is no default one set. Do you want to set a default binding to be used by the tool? y/n"
        #     if ($choice -eq 'y') {
        #         sf-iis-site-setBinding
        #     }
        # } else {
        #   sf-iis-site-setBinding -defBinding ($bindings | select -Last 1)
        # }
        if ($bindings) {
            sf-iis-site-setBinding -defBinding ($bindings | select -Last 1)
            return $true
        }
    }
    elseif ($selectedSitefinity.defaultBinding -and !(_checkDefaultBindingIsWorking)) {
        $selectedSitefinity.defaultBinding = $null
        $changed = _checkAndUpdateBindings -selectedSitefinity $selectedSitefinity
        return $true
    }
}

function _checkDefaultBindingIsWorking {
    $selectedSitefinity = sf-PSproject-get
    if (!$selectedSitefinity.websiteName) {
        return 
    }
    
    $allBindings = iis-bindings-getAll -siteName $selectedSitefinity.websiteName
    $binding = $allBindings | Where-Object { $_.domain -eq $selectedSitefinity.defaultBinding.domain -and $_.protocol -eq $selectedSitefinity.defaultBinding.protocol -and $_.port -eq $selectedSitefinity.defaultBinding.port }
    if (!(os-hosts-get | ? { $_.Contains($selectedSitefinity.defaultBinding.domain) })) {
        $binding = $null
    }

    return $binding
}