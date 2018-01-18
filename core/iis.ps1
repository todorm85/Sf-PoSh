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

    $context = _get-selectedProject

    $binPath = "$($context.webAppPath)\bin\dummy.sf"
    New-Item -ItemType file -Path $binPath > $null
    Remove-Item -Path $binPath > $null

    if ($start) {
        Start-Sleep -s 1
        _sf-start-sitefinity
    }
}

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

    $context = _get-selectedProject
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
        & start $browserPath
    }

    $appUrl = _sf-get-appUrl
    & $browserPath "${appUrl}/Sitefinity" -noframemerging
}

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

    $context = _get-selectedProject
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
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-setup-asSubApp {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][string]$subAppName
    )

    $context = _get-selectedProject
    $dummyPath = "c:\dummySubApp"
    if (-not (Test-Path $dummyPath)) {
        New-Item $dummyPath -ItemType Directory
    }
        
    iis-set-sitePath $context.websiteName $dummyPath
    iis-new-subApp $context.websiteName $subAppName $context.webAppPath
}

function sf-remove-subApp {
    $context = _get-selectedProject
    $subAppName = iis-get-subAppName $context.websiteName
    if ($subAppName -eq $null) {
        return
    }

    iis-remove-subApp $context.websiteName $subAppName
    iis-set-sitePath $context.websiteName $context.webAppPath
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-get-poolId {
    [CmdletBinding()]
    Param()
    
    $context = _get-selectedProject

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

function _sf-create-website {
    Param(
        [string]$newWebsiteName,
        [string]$newPort,
        [string]$newAppPool
        )

    $context = _get-selectedProject
    $websiteName = $context.websiteName

    if ($context.websiteName -ne '' -and $null -ne $context.websiteName) {
        throw 'Current context already has a website assigned!'
    }

    $newAppPath = $context.webAppPath
    try {
        $site = iis-create-website -newWebsiteName $newWebsiteName -newPort $newPort -newAppPath $newAppPath -newAppPool $newAppPool
        $context.websiteName = $site.name
        _save-selectedProject $context
    } catch {
        $context.websiteName = ''
        throw "Error creating site: $_.Exception.Message"
    }
}

function _sf-delete-website {
    $context = _get-selectedProject
    $websiteName = $context.websiteName
    if ($websiteName -eq '') {
        throw "Website name not set."
    }

    $oldWebsiteName = $context.websiteName
    $context.websiteName = ''
    try {
        _save-selectedProject $context
        Remove-Item ("iis:\Sites\${websiteName}") -Force -Recurse
    } catch {
        $context.websiteName = $oldWebsiteName
        _save-selectedProject $context
        throw "Error: $_.Exception.Message"
    }
}

function _sf-get-appUrl {
    $context = _get-selectedProject
    $port = @(iis-get-websitePort $context.websiteName)[0]
    if ($port -eq '' -or $null -eq $port) {
        throw "No sitefinity port set."
    }

    $subAppName = iis-get-subAppName $context.websiteName
    if ($subAppName -ne $null) {
        return "http://localhost:${port}/${subAppName}"
    } else {
        return "http://localhost:${port}"
    }
}
