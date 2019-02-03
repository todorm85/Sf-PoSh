
function sf-rename-website {
    Param(
        [string]$newName
    )

    $context = _get-selectedProject
    try {
        iis-rename-website $context.websiteName $newName
    }
    catch {
        Write-Host "Error renaming site in IIS. Message: $_.Message"
        throw
    }
    
    $context.websiteName = $newName
    _save-selectedProject $context

}

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
function sf-browse-webSite {
    [CmdletBinding()]
    Param([switch]$useExistingBrowser)

    $appUrl = get-appUrl
    if (-not (check-domainRegistered $appUrl)) {
        $appUrl = get-appUrl -$useDevUrl
    }

    if (-not $useExistingBrowser) {
        execute-native "& Start-Process `"$browserPath`""
    }
    
    execute-native "& `"$browserPath`" `"${appUrl}/Sitefinity`" -noframemerging"
}

<#
.SYNOPSIS
Creates a website for the given project or currently selected one.

.PARAMETER context
The project for which to create a website.

.NOTES
General notes
#>
function create-website {
    Param(
        [SfProject]$context
    )

    if (-not $context) {
        $context = _get-selectedProject
    }

    $port = 2111
    while (!(os-test-isPortFree $port) -or !(iis-test-isPortFree $port)) {
        $port++
    }

    while ([string]::IsNullOrEmpty($context.websiteName) -or (iis-test-isSiteNameDuplicate $context.websiteName)) {
        throw "Website with name $($context.websiteName) already exists or no name provided:"
    }


    $newAppPath = $context.webAppPath
    $newAppPool = $context.id
    $domain = generate-domainName -context $context
    try {
        iis-create-website -newWebsiteName $context.websiteName -domain $domain -newPort $port -newAppPath $newAppPath -newAppPool $newAppPool

    }
    catch {
        throw "Error creating site: $_"
    }

    _save-selectedProject $context

    try {
        if ($domain) {
            Add-ToHostsFile -address "127.0.0.1" -hostname $domain
        }
    }
    catch {
        Write-Error "Error adding domain to hosts file."
    }

    try {
        sql-create-login -name "IIS APPPOOL\${newAppPool}"
    }
    catch {
        Write-Error "Error creating login user in SQL server for IIS APPPOOL\${newAppPool}. Message:$_"
        delete-website $context
        $context.websiteName = ''
        _save-selectedProject $context
    }
}

function delete-website ([SfProject]$context) {
    if (-not $context) {
        $context = _get-selectedProject
    }

    $websiteName = $context.websiteName
    if ($websiteName -eq '') {
        throw "Website name not set."
    }
    
    $appPool = @(iis-get-siteAppPool $websiteName)
    $domain = (iis-get-binding $websiteName).domain
    $context.websiteName = ''
    try {
        _save-selectedProject $context
        Remove-Item ("iis:\Sites\${websiteName}") -Force -Recurse
    }
    catch {
        $context.websiteName = $websiteName
        _save-selectedProject $context
        throw "Error deleting website ${websiteName}: $_"
    }

    try {
        Remove-Item ("iis:\AppPools\$appPool") -Force -Recurse
    }
    catch {
        Write-Error "Error removing app pool $appPool Error: $_"
    }

    try {
        sql-delete-login -name "IIS APPPOOL\${appPool}"
    }
    catch {
        Write-Error "Error removing sql login (IIS APPPOOL\${appPool}) Error: $_"
    }

    try {
        if ($domain) {
            Remove-FromHostsFile -hostname $domain > $null
        }
    }
    catch {
        Write-Error "Error removing domain from hosts file. Error $_"        
    }
}

function change-domain {
    param (
        $context,
        $domainName
    )

    if (-not $context) {
        $context = _get-selectedProject
    }

    $websiteName = $context.websiteName

    $oldDomain = (iis-get-binding $websiteName).domain
    if ($oldDomain) {
        try {
            Remove-FromHostsFile -hostname $oldDomain > $null
        }
        catch {
            Write-Error "Error cleaning previous domain not found in hosts file."            
        }
    }

    $port = (iis-get-binding $websiteName).port
    if ($port) {
        iis-set-binding $websiteName $domainName $port
        Add-ToHostsFile -address 127.0.0.1 -hostname $domainName
    }
    else {
        throw "No binding found for site $websiteName"
    }
}