<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function subApp-set {
    
    Param(
        [Parameter(Mandatory = $true)][string]$subAppName
    )

    $project = proj-getCurrent
    $subApp = iis-get-subAppName -websiteName $project.websiteName
    if ($subApp) {
        return
    }
    
    $dummyPath = "c:\sf-dev-temp"
    if (-not (Test-Path $dummyPath)) {
        New-Item $dummyPath -ItemType Directory
    }
        
    iis-set-sitePath $project.websiteName $dummyPath
    iis-new-subApp $project.websiteName $subAppName $project.webAppPath
}

function subApp-remove {
    $project = proj-getCurrent

    $subAppName = iis-get-subAppName $project.websiteName
    if ($null -eq $subAppName) {
        return
    }

    iis-remove-subApp $project.websiteName $subAppName
    iis-set-sitePath $project.websiteName $project.webAppPath
}
