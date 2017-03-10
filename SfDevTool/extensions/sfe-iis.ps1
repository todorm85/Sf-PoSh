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
function sf-setup-asSubApp {
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
function sf-get-poolId {
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
