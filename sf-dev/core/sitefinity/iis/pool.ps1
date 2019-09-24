<#
    .SYNOPSIS 
    Resets the current sitefinity web app threads in the app pool in IIS, without resetting the app pool.
    .PARAMETER start
    If switch is passed sitefinity is automatically initialized after the reset.
    .OUTPUTS
    None
#>
function Reset-Thread {
    
    Param([switch]$start,
    [SfProject]$project)

    if (!$project) {
        $project = Get-CurrentProject
    }

    $binPath = "$($project.webAppPath)\bin\dummy.sf"
    New-Item -ItemType file -Path $binPath > $null
    Remove-Item -Path $binPath > $null

    if ($start) {
        Start-Sleep -s 1
        start-app_
    }
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function Reset-Pool {
    
    Param(
        [switch]$start,
        [SfProject]$project
    )

    if (!$project) {
        $project = Get-CurrentProject
    }

    $appPool = @(iis-get-siteAppPool $project.websiteName)
    if ($appPool -eq '') {
        throw "No app pool set."
    }

    Restart-WebItem ("IIS:\AppPools\" + $appPool)
    if ($start) {
        Start-Sleep -s 1
        start-app_
    }
}

function Stop-Pool ([SfProject]$context) {
    if (-not $context) {
        $context = Get-CurrentProject
    }

    try {
        $appPool = @(iis-get-siteAppPool $context.websiteName)
    }
    catch {
        throw "Error getting app pool $_"
    }

    Stop-WebItem ("IIS:\AppPools\" + $appPool)
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function Change-Pool {
    
    Param()

    $context = Get-CurrentProject
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
function Get-PoolId {
    
    Param()
    
    $context = Get-CurrentProject

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
