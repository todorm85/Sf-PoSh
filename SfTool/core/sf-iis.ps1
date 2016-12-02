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

    $context = _sf-get-context
    $port = @(iis-get-websitePort $context.websiteName)[0]
    if ($port -eq '' -or $null -eq $port) {
        throw "No sitefinity port set."
    }

    if (-not $useExistingBrowser) {
        & start $browserPath
    }

    & $browserPath "http://localhost:${port}/Sitefinity" -noframemerging
}

<#
    .SYNOPSIS 
    Resets the current sitefinity web app threads in the app pool in IIS, without resetting the app pool.
    .PARAMETER start
    If switch is passed sitefinity is automatically initialized after the reset.
    .OUTPUTS
    None
#>
function sf-reset-thread {
    [CmdletBinding()]
    Param([switch]$start)

    $context = _sf-get-context

    $binPath = "$($context.webAppPath)\bin\dummy.sf"
    New-Item -ItemType file -Path $binPath > $null
    Remove-Item -Path $binPath > $null

    if ($start) {
        Start-Sleep -s 1
        _sf-start-sitefinity
    }
}

function _sf-create-website {
    Param(
        [string]$newWebsiteName,
        [string]$newPort,
        [string]$newAppPool
        )

    $context = _sf-get-context
    $websiteName = $context.websiteName

    if ($context.websiteName -ne '' -and $null -ne $context.websiteName) {
        throw 'Current context already has a website assigned!'
    }

    $newAppPath = $context.webAppPath
    try {
        $site = iis-create-website -newWebsiteName $newWebsiteName -newPort $newPort -newAppPath $newAppPath -newAppPool $newAppPool
        $context.websiteName = $site.name
        _sfData-save-context $context
    } catch {
        $context.websiteName = ''
        throw "Error creating site: $_.Exception.Message"
    }
}

function _sf-delete-website {
    $context = _sf-get-context
    $websiteName = $context.websiteName
    if ($websiteName -eq '') {
        throw "Website name not set."
    }

    $oldWebsiteName = $context.websiteName
    $context.websiteName = ''
    try {
        _sfData-save-context $context
        New-Item ("iis:\Sites\${websiteName}")
    } catch {
        $context.websiteName = $oldWebsiteName
        _sfData-save-context $context
        throw "Error: $_.Exception.Message"
    }
}