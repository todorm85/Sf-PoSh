$Global:SfEvents_OnAfterProjectSet += {
    sf-serverCode-deployDirectory "$PSScriptRoot\serverCode" "$($Global:sf.appRelativeServerCodeRootPath)\sites"
}

function sf-seed-Sites-create {
    param (
        $totalSitesCount = 2,
        [switch]$duplicateFromDefaultSite
    )
    
    sf-serverCode-run "SitefinityWebApp.SfDev.Sites" -methodName "Seed" -parameters @($totalSitesCount, $duplicateFromDefaultSite) > $null
}