if ($false) {
    . .\..\sf-all-dependencies.ps1 # needed for intellisense
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

New-Alias -name rt -value sf-reset-thread

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-reset-pool {
    [CmdletBinding()]
    Param([switch]$start)

    $context = _sf-get-context
    $appPool = @(iis-get-siteAppPool $context.websiteName)
    if ($appPool -eq '') {
           throw "No app pool set."
    }

    Restart-WebItem ("IIS:\AppPools\" + $appPool)
    if ($start) {
        Start-Sleep -s 1
        _sf-start-sitefinity
    }
}

New-Alias -name rp -value sf-reset-pool

function sf-rename-website {
    Param(
        [string]$newName
    )

    $context = _sf-get-context
    try {
        iis-rename-website $context.websiteName $newName
    }
    catch {
        Write-Host "Error renaming site in IIS. Message: $_.Message"
        throw
    }
    
    $context.websiteName = $newName
    _sfData-save-context $context

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
        Remove-Item ("iis:\Sites\${websiteName}") -Force -Recurse
    } catch {
        $context.websiteName = $oldWebsiteName
        _sfData-save-context $context
        throw "Error: $_.Exception.Message"
    }
}

function _sf-get-appUrl {
    $context = _sf-get-context
    $port = @(iis-get-websitePort $context.websiteName)[0]
    if ($port -eq '' -or $null -eq $port) {
        throw "No sitefinity port set."
    }

    $subAppName = iis-get-subAppName
    if ($subAppName -ne $null) {
        return "http://localhost:${port}/${subAppName}"
    } else {
        return "http://localhost:${port}"
    }
}
