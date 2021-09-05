$Global:SfEvents_OnAfterProjectSet += {
    # remove dependencies to tests
    # sf-serverCode-deployDirectory "$PSScriptRoot\serverCode" "$($Global:sfe.appRelativeServerCodeRootPath)\pages"
}

<#
.SYNOPSIS
Seeds a hierarchy of pages into Sitefinity instance. The system must have an Admin user with email and username admin@test.test
.PARAMETER pagesPerLevelCount
The number of child pages for each page
.PARAMETER levelsCount
The depth of the hierarchy of pages
.PARAMETER forAllSites
Whether to generate the same hierarchy for every site in Sitefinity
#>
function sf-seed-Pages {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { $_ -gt 0 })]
        [int]
        $pagesPerLevelCount,

        [Parameter(Mandatory = $true)]
        [ValidateScript( { $_ -gt 0 })]
        [int]
        $levelsCount,
        
        [switch]
        $forAllSites
    )
    
    $allSitesValue = "false"
    if ($forAllSites) { $allSitesValue = "true" }

    sf-serverCode-run "SitefinityWebApp.SfDev.Pages" -methodName "Seed" -parameters @($pagesPerLevelCount, $levelsCount, $allSitesValue) > $null
}

function sf-seed-Pages-deleteAll {
    param (
        [switch]$allSites
    )

    $allSitesValue = "false"
    if ($forAllSites) { $allSitesValue = "true" }
    sf-serverCode-run "SitefinityWebApp.SfDev.Pages" -methodName "DeleteAll" -parameters @($allSitesValue) > $null
}

function sf-seed-Pages-AddContentWidgetToAllPages {
    sf-serverCode-run "SitefinityWebApp.SfDev.Pages" -methodName "AddContentWidgetToAllPages" > $null
}

function sf-seed-Pages-CreateChildPages {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$urlName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$countRaw,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$pageTitle
    )

    sf-serverCode-run "SitefinityWebApp.SfDev.Pages" -methodName "CreateChildPages" -parameters @($urlName, $countRaw, $pageTitle) > $null
}