
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

New-Alias -name rep -value sf-reset-pool

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-change-appPool {
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
        [switch]$revert
    )

    $context = _sf-get-context
    if (-not $revert) {
        
        Get-Item ("iis:\Sites\$($context.websiteName)") | Set-ItemProperty -Name "physicalPath" -Value "c:\"

        New-Item "IIS:\Sites\$($context.websiteName)\subApp" -physicalPath $context.webAppPath -type "Application"
    } else {
        Remove-Item "IIS:\Sites\$($context.websiteName)\subApp" -force -recurse -Confirm:$false

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
function sf-get-appPoolId () {
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