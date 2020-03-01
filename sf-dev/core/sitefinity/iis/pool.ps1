<#
    .SYNOPSIS 
    Resets the current sitefinity web app threads in the app pool in IIS, without resetting the app pool.
    .PARAMETER start
    If switch is passed sitefinity is automatically initialized after the reset.
    .OUTPUTS
    None
#>
function sf-iisAppPool-ResetThread {
    Param([switch]$start)

    $project = sf-project-getCurrent

    $binPath = "$($project.webAppPath)\bin\dummy.sf"
    New-Item -ItemType file -Path $binPath > $null
    Remove-Item -Path $binPath > $null

    if ($start) {
        Start-Sleep -s 1
        sf-app-waitForSitefinityToStart
    }
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-iisAppPool-Reset {
    
    Param(
        [switch]$start
    )

    $project = sf-project-getCurrent

    $appPool = @(iis-get-siteAppPool $project.websiteName)
    if ($appPool -eq '') {
        throw "No app pool set."
    }

    Restart-WebItem ("IIS:\AppPools\" + $appPool)
    if ($start) {
        Start-Sleep -s 1
        sf-app-waitForSitefinityToStart
    }
}

function sf-iisAppPool-Stop {
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
