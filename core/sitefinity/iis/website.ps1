
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

    if (-not $useExistingBrowser) {
        execute-native "& Start-Process `"$browserPath`""
    }

    $appUrl = get-appUrl
    if (-not (check-domainRegistered $appUrl)) {
        $appUrl = get-appUrl -$useDevUrl
    }

    execute-native "& `"$browserPath`" `"${appUrl}/Sitefinity`" -noframemerging"
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-add-sitePort {
    [CmdletBinding()]
    Param(
        [int]$port = 1111,
        [switch]$auto
    )

    while (!(os-test-isPortFree $port) -or !(iis-test-isPortFree $port)) {
        if ($auto) {
            $port++
        }
        else {
            $port = Read-Host -Prompt 'Port used. Enter new: '
        }
    }

    $context = _get-selectedProject
    $websiteName = $context.websiteName

    iis-add-sitePort -name $websiteName -port $port
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-remove-sitePorts {
    [CmdletBinding()]
    Param(
        [string]$port
    )

    $context = _get-selectedProject
    $websiteName = $context.websiteName

    $ports = iis-get-websitePort $websiteName
    ForEach ($usedPort in $ports) {
        Remove-WebBinding -Name $websiteName -port $usedPort
    }
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

    $port = 1111
    while (!(os-test-isPortFree $port) -or !(iis-test-isPortFree $port)) {
        $port++
    }

    while ([string]::IsNullOrEmpty($context.websiteName) -or (iis-test-isSiteNameDuplicate $context.websiteName)) {
        throw "Website with name $($context.websiteName) already exists or no name provided:"
    }


    $newAppPath = $context.webAppPath
    $newAppPool = $context.id
    try {
        iis-create-website -newWebsiteName $context.websiteName -newPort $port -newAppPath $newAppPath -newAppPool $newAppPool

        _save-selectedProject $context
    }
    catch {
        throw "Error creating site: $_"
    }

    try {
        sql-create-login -name "IIS APPPOOL\${newAppPool}"
    }
    catch {
        throw "Error creating login user in SQL server for IIS APPPOOL\${newAppPool}. Message:$_"
        delete-website $context
        $context.websiteName = ''
        _save-selectedProject $context
    }

    try {
        $domain = get-domain -context $context
        Show-Domains | ForEach-Object {
            $found = $_ -match "^$domain .*$"
        } | Out-Null
        
        if ($found) {
            Remove-Domain $domain
        }

        Add-Domain $domain $port   
    }
    catch {
        Write-Warning "Error adding domain registration $domain Error: $_"
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
        throw "Error removing app pool $appPool Error: $_"
    }

    try {
        sql-delete-login -name "IIS APPPOOL\${appPool}"
    }
    catch {
        throw "Error removing sql login (IIS APPPOOL\${appPool}) Error: $_"
    }

    try {
        $domain = get-domain -context $context
        Remove-Domain $domain
    }
    catch {
        throw "Error removing domain registration $domain Error: $_"
    }
}