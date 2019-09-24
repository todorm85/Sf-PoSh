<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-setup-asSubApp {
    
    Param(
        [Parameter(Mandatory = $true)][string]$subAppName,
        [SfProject]$project
    )

    if (!$project) {
        $project = sf-get-currentProject
    }

    $subApp = iis-get-subAppName -websiteName $project.websiteName
    if ($subApp) {
        return
    }
    
    $dummyPath = "c:\dummySubApp"
    if (-not (Test-Path $dummyPath)) {
        New-Item $dummyPath -ItemType Directory
    }
        
    iis-set-sitePath $project.websiteName $dummyPath
    iis-new-subApp $project.websiteName $subAppName $project.webAppPath
}

function sf-remove-subApp {
    Param(
        [SfProject]$project
    )
    
    if (!$project) {
        $project = sf-get-currentProject
    }

    $subAppName = iis-get-subAppName $project.websiteName
    if ($null -eq $subAppName) {
        return
    }

    iis-remove-subApp $project.websiteName $subAppName
    iis-set-sitePath $project.websiteName $project.webAppPath
}
