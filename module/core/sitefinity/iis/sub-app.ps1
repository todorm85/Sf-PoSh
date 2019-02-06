<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-setup-asSubApp {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$subAppName
    )

    $context = _get-selectedProject
    $subApp = iis-get-subAppName -websiteName $context.websiteName
    if ($subApp) {
        return
    }
    
    $dummyPath = "c:\dummySubApp"
    if (-not (Test-Path $dummyPath)) {
        New-Item $dummyPath -ItemType Directory
    }
        
    iis-set-sitePath $context.websiteName $dummyPath
    iis-new-subApp $context.websiteName $subAppName $context.webAppPath
}

function sf-remove-subApp {
    $context = _get-selectedProject
    $subAppName = iis-get-subAppName $context.websiteName
    if ($subAppName -eq $null) {
        return
    }

    iis-remove-subApp $context.websiteName $subAppName
    iis-set-sitePath $context.websiteName $context.webAppPath
}
