if ($false) {
    . .\..\sf-all-dependencies.ps1 # needed for intellisense
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
        & start $browserPath
    }

    $appUrl = _sf-get-appUrl
    & $browserPath "${appUrl}/Sitefinity" -noframemerging
}

New-Alias -name bw -value sf-browse-webSite

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

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-change-pool {
    [CmdletBinding()]
    Param()

    $context = _sf-get-context
    $websiteName = $context.websiteName

    if ($websiteName -eq '') {
        throw "Website name not set."
    }

    # display app pools with websites
    $appPools = @(Get-ChildItem ("IIS:\AppPools"))
    $appPools

    foreach ($pool in $appPools) {
        $index = [array]::IndexOf($appPools, $pool)
        Write-Host  $index : $pool.name
    }

    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose appPool'
        $selectedPool = $appPools[$choice]
        if ($null -ne $selectedPool) {
            break;
        }
    }

    $selectedPool
    try {
        Set-ItemProperty "IIS:\Sites\${websiteName}" -Name "applicationPool" -Value $selectedPool.name
    } catch {
        throw "Could not set website pools"
    }
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

    while(!(os-test-isPortFree $port) -or !(iis-test-isPortFree $port)) {
        if ($auto) {
            $port++
        } else {
            $port = Read-Host -Prompt 'Port used. Enter new: '
        }
    }

    $context = _sf-get-context
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

    $context = _sf-get-context
    $websiteName = $context.websiteName

    $ports = iis-get-websitePort $websiteName
    ForEach ($usedPort in $ports) {
        Remove-WebBinding -Name $websiteName -port $usedPort
    }
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-setup-asSubApp () {
    [CmdletBinding()]
    Param(
        [string]$subAppName,
        [switch]$revert
    )

    $context = _sf-get-context
    if (-not $revert) {
        $dummyPath = "c:\dummySubApp"
        if (-not (Test-Path $dummyPath)) {
            New-Item $dummyPath -ItemType Directory
        }

        Get-Item ("iis:\Sites\$($context.websiteName)") | Set-ItemProperty -Name "physicalPath" -Value $dummyPath

        New-Item "IIS:\Sites\$($context.websiteName)\${subAppName}" -physicalPath $context.webAppPath -type "Application"
    } else {
        $subAppName = iis-get-subAppName
        if ($subAppName -eq $null) {
            return
        }

        Remove-Item "IIS:\Sites\$($context.websiteName)\${subAppName}" -force -recurse -Confirm:$false

        Get-Item ("iis:\Sites\$($context.websiteName)") | Set-ItemProperty -Name "physicalPath" -Value $context.webAppPath
    }

}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-get-poolId () {
    [CmdletBinding()]
    Param()
    
    $context = _sf-get-context

    $appPools = iis-show-appPoolPid
    $currentAppPool = @(iis-get-siteAppPool $context.websiteName)
    foreach ($entry in $appPools) {
        $entry -match "\(applicationPool:(?<pool>.*?)\)" > $Null
        $entryPool = $matches["pool"]
        if ($entryPool -eq $currentAppPool) {
            Write-Host $entry
            return
        }
    }
}

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
