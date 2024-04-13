<#
    .SYNOPSIS
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-iis-subApp-set {
    Param(
        [Parameter(Mandatory = $true)][string]$subAppName
    )

    $project = sf-project-get
    $subApp = sf-iis-site-getSubAppName -websiteName $project.websiteName
    if ($subApp) {
        Write-Warning "Application already set up as subapp."
        return
    }

    $dummyPath = "c:\sf-posh-temp"
    if (-not (Test-Path $dummyPath)) {
        New-Item $dummyPath -ItemType Directory
    }

    iis-set-sitePath $project.websiteName $dummyPath
    iis-new-subApp $project.websiteName $subAppName $project.webAppPath
}

function sf-iis-subApp-remove {
    $project = sf-project-get

    $subAppName = sf-iis-site-getSubAppName $project.websiteName
    if ($null -eq $subAppName) {
        Write-Warning "Application not set up as subapp."
        return
    }

    iis-remove-subApp $project.websiteName $subAppName
    iis-set-sitePath $project.websiteName $project.webAppPath
}
