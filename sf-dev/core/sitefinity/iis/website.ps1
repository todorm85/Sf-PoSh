
function sf-rename-website {
    Param(
        [string]$newName
    )

    $context = sf-get-currentProject
    try {
        iis-rename-website $context.websiteName $newName
    }
    catch {
        throw "Error renaming site in IIS. Message: $_.Message"
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
    
    Param(
        [switch]$useExistingBrowser,
        [SfProject]$project
    )

    if (!$project) {
        $project = sf-get-currentProject
    }

    $appUrl = _get-appUrl -context $project
    if (!(Test-Path $browserPath)) {
        throw "Invalid browser path configured ($browserPath). Configure it in $Script:userConfigPath -> browserPath"
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
function sf-create-website {
    Param(
        [SfProject]$context
    )

    if (-not $context) {
        $context = sf-get-currentProject
    }

    $port = 2111
    while (!(os-test-isPortFree $port) -or !(iis-test-isPortFree $port)) {
        $port++
    }

    while ([string]::IsNullOrEmpty($context.id) -or (iis-test-isSiteNameDuplicate $context.id)) {
        throw "Website with name $($context.id) already exists or no name provided:"
    }

    if (!$context.websiteName) {
        $context.websiteName = $context.id
    }
    
    $newAppPath = $context.webAppPath
    $newAppPool = $context.id
    $domain = _generate-domainName -context $context
    try {
        iis-create-website -newWebsiteName $context.websiteName -domain $domain -newPort $port -newAppPath $newAppPath -newAppPool $newAppPool > $null
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
}

function _delete-website ([SfProject]$context) {
    if (-not $context) {
        $context = sf-get-currentProject
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
        if ($domain) {
            Remove-FromHostsFile -hostname $domain > $null
        }
    }
    catch {
        Write-Error "Error removing domain from hosts file. Error $_"        
    }
}

function _change-domain {
    param (
        $context,
        $domainName
    )

    if (-not $context) {
        $context = sf-get-currentProject
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
