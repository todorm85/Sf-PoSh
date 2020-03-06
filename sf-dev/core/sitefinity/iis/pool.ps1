<#
    .SYNOPSIS
    Resets the current sitefinity web app threads in the app pool in IIS, without resetting the app pool.
    .PARAMETER start
    If switch is passed sitefinity is automatically initialized after the reset.
    .OUTPUTS
    None
#>
function sd-iisAppPool-ResetThread {
    Param([switch]$start)

    $project = sd-project-getCurrent

    $binPath = "$($project.webAppPath)\bin\dummy.sf"
    New-Item -ItemType file -Path $binPath > $null
    Remove-Item -Path $binPath > $null

    if ($start) {
        Start-Sleep -s 1
        sd-app-waitForSitefinityToStart
    }
}

<#
    .SYNOPSIS
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sd-iisAppPool-Reset {

    Param(
        [switch]$start
    )

    $project = sd-project-getCurrent

    $appPool = Get-IISSite -Name $project.websiteName | Get-IISAppPool | Select-Object -ExpandProperty Name
    if ($appPool -eq '') {
        throw "No app pool set."
    }

    Restart-WebItem ("IIS:\AppPools\" + $appPool)
    if ($start) {
        Start-Sleep -s 1
        sd-app-waitForSitefinityToStart
    }
}

function sd-iisAppPool-Stop {
    $websiteName = (sd-project-getCurrent).websiteName
    $errors = ''
    try {
        $appPool = Get-IISSite -Name $websiteName | Get-IISAppPool | Select-Object -ExpandProperty Name
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
