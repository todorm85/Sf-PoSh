function sf-license-set {
    param(
        [ValidateSet("Default", "SingleSite", "MultiSite")]
        [string]$mode
    )
    
    [SfProject]$proj = sf-project-get
    $licensesPath = "$($proj.webAppPath)\App_Data\Sitefinity"
    $currentLicensePath = "$licensesPath\Sitefinity.lic"
    $defaultLicenseBackupPath = "$licensesPath\Sitefinity.lic.bak"
    if (!(Test-Path $defaultLicenseBackupPath)) {
        Copy-Item -Path $currentLicensePath -Destination $defaultLicenseBackupPath
    }

    $singleSiteLicensePath = "$licensesPath\Sitefinity-SingleSite.lic"
    $multiSiteLicensePath = "$licensesPath\Sitefinity-MultiSite.lic"
    switch ($mode) {
        "Default" { Copy-Item $defaultLicenseBackupPath $currentLicensePath -Force -ErrorAction Stop }
        "SingleSite" { Copy-Item $singleSiteLicensePath $currentLicensePath -Force -ErrorAction Stop}
        "MultiSite" { Copy-Item $multiSiteLicensePath $currentLicensePath -Force -ErrorAction Stop}
        Default { throw "Invalid mode" }
    }

    sf-app-ensureRunning
}