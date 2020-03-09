function sd-iisSite-getBinding {
    [SfProject]$context = sd-project-getCurrent
    if (!$context) {
        throw "No project selected."
    }

    if (!$context.websiteName) {
        Write-Warning "No website for current project."
        return
    }

    [SiteBinding]$binding = $null
    $allBindings = iis-bindings-getAll -siteName $context.websiteName
    if ($context.defaultBinding) {
        $binding = $allBindings | Where-Object { $_.domain -eq $context.defaultBinding.domain -and $_.protocol -eq $context.defaultBinding.protocol -and $_.port -eq $context.defaultBinding.port }
    }

    if (!$binding) {
        $binding = $allBindings | Select-Object -Last 1
    }

    return $binding
}

function sd-iisSite-setBinding {
    [SfProject]$project = sd-project-getCurrent
    $selectedBinding = _promptBindings
    $project.defaultBinding = [SiteBinding]$defBinding = @{
        protocol = $selectedBinding.protocol
        domain   = $selectedBinding.domain
        port     = $selectedBinding.port
    }

    sd-project-saveCurrent -context $project
}

function sd-iisSite-getUrl {
    [SiteBinding]$binding = sd-iisSite-getBinding
    return _iisSite-appendSubAppPath "$($binding.protocol)://$($binding.domain):$($binding.port)"
}

function sd-iisSite-changeDomain {
    param (
        $domainName
    )

    [SiteBinding]$binding = sd-iisSite-getBinding
    if ($binding) {
        [SfProject]$p = sd-project-getCurrent
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
            sd-project-saveCurrent -context $p
        }
    }
    else {
        Write-Warning "No binding found for site $websiteName"
    }
}

function _iisSite-appendSubAppPath {
    param($path)

    $context = sd-project-getCurrent
    $subAppName = sd-iisSite-getSubAppName -websiteName $context.websiteName
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
    [SfProject]$project = sd-project-getCurrent
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
