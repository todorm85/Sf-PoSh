
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
function sf-iisSite-browse {
    Param(
        [switch]$useExistingBrowser
    )

    $browserPath = $GLOBAL:sf.Config.browserPath;
    [SfProject]$project = sf-project-getCurrent
    if (!$project) {
        throw "No project selected."
    }

    if (!$project.websiteName) { throw "No site defined for project." }

    if (!(iis-site-isStarted $project.websiteName)) {
        throw "Website is stopped in IIS."
    }

    $appUrl = sf-iisSite-getUrl
    if (!(Test-Path $browserPath)) {
        throw "Invalid browser path configured ($browserPath). Configure it in $($global:sf.config.userConfigPath). -> browserPath"
    }

    os-browseUrl -url "${appUrl}/Sitefinity" -openInSameWindow:$useExistingBrowser
}

<#
.SYNOPSIS
Creates a website for the given project or currently selected one.

.PARAMETER context
The project for which to create a website.

.NOTES
General notes
#>
function sf-iisSite-new {
    param(
        [SfProject]$context
    )

    if (!$context) {
        $context = sf-project-getCurrent
    }
    
    $siteExists = Get-Website | ? name -eq $context.id
    # do not use get-iisapppool - does not return latest
    $poolExists = Get-ChildItem "IIS:\AppPools" | ? name -eq $context.id
    if ([string]::IsNullOrEmpty($context.id) -or $siteExists -or $poolExists) {
        throw "Website with name $($context.id) already exists or no name provided:"
    }

    if (!$context.websiteName) {
        $context.websiteName = $context.id
    }

    $newAppPath = $context.webAppPath
    $newAppPool = $context.id
    $domain = _generateDomainName -context $context
    try {
        iis-website-create -newWebsiteName $context.websiteName -domain $domain -newAppPath $newAppPath -newAppPool $newAppPool > $null
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

function sf-iisSite-delete {
    $proj = sf-project-getCurrent
    if (!$proj) {
        throw "No project!"
    }
    
    $websiteName = $proj.websiteName
    if (!$websiteName) {
        throw "Website name not set."
    }

    $appPool = (Get-Website -Name $websiteName).applicationPool
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

function sf-iisSite-getSubAppName {
    $proj = sf-project-getCurrent
    [SfProject]$proj = sf-project-getCurrent
    Get-WebApplication -Site $proj.websiteName | ? { $_.PhysicalPath.ToLower() -eq $proj.webAppPath } | % { $_.path.TrimStart('/') }
}
