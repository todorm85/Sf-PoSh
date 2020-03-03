
<#
    .SYNOPSIS 
    Opens the current sitefinity webapp in the browser.
    .DESCRIPTION
    If an existing sitefinity web app without a solution was imported nothing is done.
    .PARAMETER useExistingBrowser
    If switch is passed the last browser that was on focus is used, otherwise a new browser instance is launched.
    .OUTPUTS
    None
#>
function sd-iisSite-browse {
    Param(
        [switch]$useExistingBrowser
    )

    $browserPath = $GLOBAL:sf.Config.browserPath;
    $appUrl = sd-iisSite-getUrl
    if (!(Test-Path $browserPath)) {
        throw "Invalid browser path configured ($browserPath). Configure it in $Script:moduleUserDir -> browserPath"
    }

    if (-not $useExistingBrowser) {
        execute-native "& Start-Process `"$browserPath`"" -successCodes @(100)
    }
    
    execute-native "& `"$browserPath`" `"${appUrl}/Sitefinity`" -noframemerging" -successCodes @(100)
}

<#
.SYNOPSIS
Creates a website for the given project or currently selected one.

.PARAMETER context
The project for which to create a website.

.NOTES
General notes
#>
function sd-iisSite-new {
    Write-Information "Creating website..."

    $context = sd-project-getCurrent

    $port = 2111
    while (!(os-test-isPortFree $port) -or !(iis-isPortFree $port)) {
        $port++
    }

    $siteExists = @(Get-Website | ? { $_.name -eq $context.id }).Count -gt 0
    while ([string]::IsNullOrEmpty($context.id) -or $siteExists) {
        throw "Website with name $($context.id) already exists or no name provided:"
    }

    if (!$context.websiteName) {
        $context.websiteName = $context.id
    }
    
    $newAppPath = $context.webAppPath
    $newAppPool = $context.id
    $domain = _generateDomainName -context $context
    try {
        iis-website-create -newWebsiteName $context.websiteName -domain $domain -newPort $port -newAppPath $newAppPath -newAppPool $newAppPool > $null
    }
    catch {
        throw "Error creating site: $_"
    }

    try {
        if ($domain) {
            os-hosts-add -address "127.0.0.1" -hostname $domain
        }
    }
    catch {
        Write-Error "Error adding domain to hosts file."
    }
}

function sd-iisSite-delete {
    $proj = sd-project-getCurrent
    $websiteName = $proj.websiteName
    if (!$websiteName) {
        throw "Website name not set."
    }
    
    $appPool = Get-IISSite -Name $websiteName | Get-IISAppPool | Select-Object -ExpandProperty Name
    $domains = iis-bindings-getAll -siteName $websiteName | ? { $_.domain } | select -ExpandProperty domain
    $errors = ''
    try {
        Remove-Item ("iis:\Sites\${websiteName}") -Force -Recurse -ErrorAction SilentlyContinue -ErrorVariable +errors
    }
    catch {
        $errors += "Error deleting website ${websiteName}: $_"
    }

    try {
        Remove-Item ("iis:\AppPools\$appPool") -Force -Recurse -ErrorAction SilentlyContinue -ErrorVariable +errors
    }
    catch {
        $errors += "Error removing app pool $appPool Error: $_"
    }

    try {
        if ($domains) {
            $domains | % { os-hosts-remove -hostname $_ > $null }
        }
    }
    catch {
        $errors += "Error removing domain from hosts file. Error $_"        
    }

    if ($errors) {
        throw $errors
    }
}
# todo
function sd-iisSite-changeDomain {
    param (
        $domainName,
        $oldDomain
    )

    try {
        os-hosts-remove -hostname $oldDomain > $null
    }
    catch {
        Write-Warning "Error cleaning previous domain. It was not found in hosts file."            
    }
    
    $p = sd-project-getCurrent
    $websiteName = $p.websiteName
    [SiteBinding]$binding = iis-bindings-getAll -siteName $p.websiteName | ? { $_.domain -eq $oldDomain }
    $oldBindingFound = !!$binding
    if (!$oldBindingFound) {
        $binding = sd-iisSite-getDefaultBinding
    }

    $port = if ($binding) { $binding.port } else { $null }
    if ($port) {
        if ($oldBindingFound) {
            Remove-WebBinding -Name $websiteName -Port $port -HostHeader $oldDomain -Protocol http
        }

        New-WebBinding -Name $websiteName -Protocol http -Port $port -HostHeader $domainName
        os-hosts-add -address 127.0.0.1 -hostname $domainName
    }
    else {
        throw "No binding found for site $websiteName"
    }
}

function sd-iisSite-getDefaultPort {
    $binding = sd-iisSite-getDefaultBinding
    if ($binding) {
        $binding.port
    }
    else {
        $null
    }
}

function sd-iisSite-getDefaultBinding {
    [CmdletBinding()]
    [OutputType([SiteBinding])]
    param()
    
    [SfProject]$project = sd-project-getCurrent
    if (!$project.websiteName) {
        return $null
    }

    $bindings = @(iis-bindings-getAll -siteName $project.websiteName)
    if ($bindings.Count -gt 0) {
        $bindings[$bindings.Count - 1]
    }
    else {
        $null
    }
}

function sd-iisSite-getSubAppName {
    $proj = sd-project-getCurrent    
    [SfProject]$proj = sd-project-getCurrent
    Get-WebApplication -Site $proj.websiteName | ? { $_.PhysicalPath.ToLower() -eq $proj.webAppPath } | % { $_.path.TrimStart('/') }
}
