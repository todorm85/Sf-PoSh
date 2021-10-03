<#
    .SYNOPSIS
    Resets the current sitefinity web app threads in the app pool in IIS, without resetting the app pool.
    .PARAMETER start
    If switch is passed sitefinity is automatically initialized after the reset.
    .OUTPUTS
    None
#>
function sf-iis-appPool-ResetThread {
    Param([switch]$start)

    $project = sf-PSproject-get

    $binPath = "$($project.webAppPath)\bin\dummy.sf"
    New-Item -ItemType file -Path $binPath > $null
    Remove-Item -Path $binPath > $null

    if ($start) {
        Start-Sleep -s 1
        sf-app-ensureRunning
    }
}

<#
    .SYNOPSIS
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-iis-appPool-Reset {

    Param(
        [switch]$start
    )

    $project = sf-PSproject-get

    $appPool = (Get-Website -Name $project.websiteName).applicationPool
    if ($appPool -eq '') {
        throw "No app pool set."
    }

    Restart-WebItem ("IIS:\AppPools\" + $appPool)
    if ($start) {
        Start-Sleep -s 1
        sf-app-ensureRunning
    }
}

function sf-iis-appPool-Stop {
    $websiteName = (sf-PSproject-get).websiteName
    $errors = ''
    try {
        $appPool = (Get-Website -Name $websiteName).applicationPool
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
