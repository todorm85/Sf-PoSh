function sf-upgradeFrom {
    $current = sf-project-get
    [SfProject[]]$sitefinities = sf-project-get -all
    $source = ui-promptItemSelect -items $sitefinities -propsToShow displayName,id,version
    if (!(sf-app-isInitialized -project $source)) {
        throw "Source project is not initialized."
    }

    _copyConfigs -srcApp "$($source.webAppPath)" -trgApp "$($current.webAppPath)"
    sf-iis-appPool-Reset
}

function _copyConfigs ($srcApp, $trgApp) {
    $confPath = "App_Data\Sitefinity\Configuration"
    New-Item -Path "$trgApp\$confPath" -ItemType Directory -ErrorAction SilentlyContinue
    unlock-allFiles -path "$trgApp\$confPath"
    Remove-Item -Path "$trgApp\$confPath\*" -Recurse -Force
    Copy-Item "$srcApp\$confPath\*" -Destination "$trgApp\$confPath" -Force -recurse
}