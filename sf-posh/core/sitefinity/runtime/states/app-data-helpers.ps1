
function _appData-copy ($dest) {
    [SfProject]$project = sf-project-getCurrent

    $src = "$($project.webAppPath)\App_Data\*"
    Copy-Item -Path $src -Destination $dest -Recurse -Force -Confirm:$false -Exclude $(_getSitefinityAppDataExcludeFilter)
}

function _appData-restore ($src) {
    [SfProject]$context = sf-project-getCurrent
    $webAppPath = $context.webAppPath

    _appData-remove
    Copy-Item -Path $src -Destination "$webAppPath\App_Data" -Confirm:$false -Recurse -Force -Exclude (_getSitefinityAppDataExcludeFilter) -ErrorVariable $errors -ErrorAction SilentlyContinue  # exclude is here for backward comaptibility
    if ($errors) {
        Write-Information "Some files could not be cleaned in AppData, because they might be in use."
    }
}

function _appData-remove {
    [SfProject]$context = sf-project-getCurrent
    $webAppPath = $context.webAppPath
    $originalLocation = Get-Location
    try { 
        Set-Location -Path $webAppPath
        unlock-allFiles -path "${webAppPath}\App_Data"
        $toDelete = Get-ChildItem "${webAppPath}\App_Data" -Recurse -Force -Exclude $(_getSitefinityAppDataExcludeFilter) -File
        $errors
        $toDelete | Remove-Item -Force -ErrorAction SilentlyContinue -ErrorVariable +errors
        if ($errors) {
            Write-Information "Some files in AppData folder could not be cleaned up, perhaps in use?"
        }

        # clean empty dirs
        _clean-emptyDirs -path "${webAppPath}\App_Data"
    }
    finally {
        Set-Location $originalLocation
    }
}

function _getSitefinityAppDataExcludeFilter {
    "*.pfx"
    "*.lic"
}
