<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sd-iisSubApp-set {
    Param(
        [Parameter(Mandatory = $true)][string]$subAppName
    )

    $project = sd-project-getCurrent
    $subApp = sd-iisSite-getSubAppName -websiteName $project.websiteName
    if ($subApp) {
        Write-Warning "Application already set up as subapp."
        return
    }
    
    $dummyPath = "c:\sf-dev-temp"
    if (-not (Test-Path $dummyPath)) {
        New-Item $dummyPath -ItemType Directory
    }
        
    iis-set-sitePath $project.websiteName $dummyPath
    iis-new-subApp $project.websiteName $subAppName $project.webAppPath
}

function sd-iisSubApp-remove {
    $project = sd-project-getCurrent

    $subAppName = sd-iisSite-getSubAppName $project.websiteName
    if ($null -eq $subAppName) {
        Write-Warning "Application not set up as subapp."
        return
    }

    iis-remove-subApp $project.websiteName $subAppName
    iis-set-sitePath $project.websiteName $project.webAppPath
}
