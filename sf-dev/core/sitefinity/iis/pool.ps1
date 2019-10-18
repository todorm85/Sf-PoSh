<#
    .SYNOPSIS 
    Resets the current sitefinity web app threads in the app pool in IIS, without resetting the app pool.
    .PARAMETER start
    If switch is passed sitefinity is automatically initialized after the reset.
    .OUTPUTS
    None
#>
function sf-iis-pool-resetThread {
    Param([switch]$start)

    $project = sf-proj-getCurrent

    $binPath = "$($project.webAppPath)\bin\dummy.sf"
    New-Item -ItemType file -Path $binPath > $null
    Remove-Item -Path $binPath > $null

    if ($start) {
        Start-Sleep -s 1
        sf-app-start
    }
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-iis-pool-reset {
    
    Param(
        [switch]$start
    )

    $project = sf-proj-getCurrent

    $appPool = @(iis-get-siteAppPool $project.websiteName)
    if ($appPool -eq '') {
        throw "No app pool set."
    }

    Restart-WebItem ("IIS:\AppPools\" + $appPool)
    if ($start) {
        Start-Sleep -s 1
        sf-app-start
    }
}

function sf-iis-pool-stop {
    param(
        $websiteName
    )

    $errors = ''
    try {
        $appPool = @(iis-get-siteAppPool $websiteName)
    }
    catch {
        $errors += "Error getting app pool $_"
    }

    if ($appPool) {
        Stop-WebItem ("IIS:\AppPools\" + $appPool) -ErrorVariable +errors -ErrorAction SilentlyContinue
    }
    else {
        $errors += "App pool was not found."
    }

    if ($errors) {
        throw $errors
    }
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-iis-pool-change {
    
    Param()

    $context = sf-proj-getCurrent
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
    }
    catch {
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
function sf-iis-pool-getId {
    
    Param()
    
    $context = sf-proj-getCurrent

    $appPools = iis-show-appPoolPid
    $currentAppPool = @(iis-get-siteAppPool $context.websiteName)
    foreach ($entry in $appPools) {
        $entry -match "\(applicationPool:(?<pool>.*?)\)" > $Null
        $entryPool = $matches["pool"]
        if ($entryPool -eq $currentAppPool) {
            $entry
            return
        }
    }
}
