function _appData-copy ($dest) {
    [SfProject]$project = proj-getCurrent

    $src = "$($project.webAppPath)\App_Data\*"
    Copy-Item -Path $src -Destination $dest -Recurse -Force -Confirm:$false -Exclude $(_getSitefinityAppDataExcludeFilter)
}

function _appData-restore ($src) {
    [SfProject]$context = proj-getCurrent
    $webAppPath = $context.webAppPath

    _appData-remove
    Copy-Item -Path $src -Destination "$webAppPath\App_Data" -Confirm:$false -Recurse -Force -Exclude $(_getSitefinityAppDataExcludeFilter) -ErrorVariable $errors -ErrorAction SilentlyContinue  # exclude is here for backward comaptibility
    if ($errors) {
        Write-Information "Some files could not be cleaned in AppData, because they might be in use."
    }
}

function _appData-remove {
    [SfProject]$context = proj-getCurrent
    $webAppPath = $context.webAppPath

    $toDelete = Get-ChildItem "${webAppPath}\App_Data" -Recurse -Force -Exclude $(_getSitefinityAppDataExcludeFilter) -File
    $toDelete | ForEach-Object { unlock-allFiles -path $_.FullName }
    $errors
    $toDelete | Remove-Item -Force -ErrorAction SilentlyContinue -ErrorVariable +errors
    if ($errors) {
        Write-Information "Some files in AppData folder could not be cleaned up, perhaps in use?"
    }
    
    # clean empty dirs
    do {
        $dirs = Get-ChildItem "${webAppPath}\App_Data" -directory -recurse | Where-Object { (Get-ChildItem $_.fullName).Length -eq 0 } | Select-Object -expandproperty FullName
        $dirs | ForEach-Object { Remove-Item $_ -Force }
    } while ($dirs.count -gt 0)
}

function _getSitefinityAppDataExcludeFilter {
    "*.pfx"
    "*.lic"
}