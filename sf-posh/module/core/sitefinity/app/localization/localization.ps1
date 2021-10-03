$Global:SfEvents_OnAfterProjectSet += {
    sf-serverCode-deployDirectory "$PSScriptRoot\serverCode" "$($Global:sf.appRelativeServerCodeRootPath)\localization"
}

function sf-localization-addCultures {
    param(
        [string[]]$frontendCultures,
        [string[]]$backendCultures
    )

    # sf-serverCode-run "SitefinityWebApp.SfDev.Localization" -methodName "Multi" > $null
    $config = sf-config-open -name Resources
    $root = $config["resourcesConfig"]
    if ($frontendCultures) {
        if (!$root["cultures"]) {
            $frontendCultures = @($frontendCultures) + "en"
        }

        xml-getOrCreateElementPath $root "//cultures/clear"
        foreach ($culture in $frontendCultures) {
            $cultureInfo = [System.Globalization.CultureInfo]::GetCultureInfo($culture)
            $key = [String]::Format("{0}-{1}", $cultureInfo.EnglishName, $cultureInfo.Name).ToLowerInvariant()
            $cultureEntry = xml-getOrCreateElementPath $root "//cultures/add[@key=$key]"
            $cultureEntry.SetAttribute("culture", $culture)
            $cultureEntry.SetAttribute("uiCulture", $culture)
        }
    }

    foreach ($culture in $backendCultures) {
        $cultureInfo = [System.Globalization.CultureInfo]::GetCultureInfo($culture)
        $key = [String]::Format("{0}-{1}", $cultureInfo.EnglishName, $cultureInfo.Name).ToLowerInvariant()
        $cultureEntry = xml-getOrCreateElementPath $root "//backendCultures/add[@key=$key]"
        $cultureEntry.SetAttribute("culture", $culture)
        $cultureEntry.SetAttribute("uiCulture", $culture)
    }

    sf-config-save $config    
}

function sf-localization-removeCultures {
    param(
        [string[]]$frontendCultures,
        [string[]]$backendCultures,
        [switch]$all
    )

    # sf-serverCode-run "SitefinityWebApp.SfDev.Localization" -methodName "Mono" > $null
    $config = sf-config-open -name Resources
    $root = $config["resourcesConfig"]

    if ($all) {
        xml-removeElementIfExists $root "cultures"
        xml-removeElementIfExists $root "backendCultures"
    }
    else {
        foreach ($culture in $frontendCultures) {
            $cultureInfo = [System.Globalization.CultureInfo]::GetCultureInfo($culture)
            $key = [String]::Format("{0}-{1}", $cultureInfo.EnglishName, $cultureInfo.Name).ToLowerInvariant()
            xml-removeElementIfExists $root "cultures/add[@key='$key']"
        }
        
        if ($root["cultures"].ChildNodes.Count -eq 1) {
            xml-removeElementIfExists $root "cultures"
        }
        
        foreach ($culture in $backendCultures) {
            $cultureInfo = [System.Globalization.CultureInfo]::GetCultureInfo($culture)
            $key = [String]::Format("{0}-{1}", $cultureInfo.EnglishName, $cultureInfo.Name).ToLowerInvariant()
            xml-removeElementIfExists $root "backendCultures/add[@key='$key']"
        }
    }
    
    sf-config-save $config
}

function sf-localization-setDefaultCulture {
    param(
        $frontendCulture,
        $backendCulture
    )

    # sf-serverCode-run "SitefinityWebApp.SfDev.Localization" -methodName "Multi" > $null
    $config = sf-config-open -name Resources
    $root = $config["resourcesConfig"]

    if ($frontendCulture) {
        $cultureInfo = [System.Globalization.CultureInfo]::GetCultureInfo($frontendCulture)
        $key = [String]::Format("{0}-{1}", $cultureInfo.EnglishName, $cultureInfo.Name).ToLowerInvariant()
        $root.SetAttribute("defaultCultureKey", $key)
    }

    if ($backendCulture) {
        $cultureInfo = [System.Globalization.CultureInfo]::GetCultureInfo($backendCulture)
        $key = [String]::Format("{0}-{1}", $cultureInfo.EnglishName, $cultureInfo.Name).ToLowerInvariant()
        $root.SetAttribute("defaultBackendCultureKey", $key)
    }

    sf-config-save $config
}

function sf-localization-setSiteCultures {
    param (
        [string[]]$cultures,
        [int]$siteIndex = 0
    )
    
    $culturesInput = _getInputFromArray $cultures
    sf-serverCode-run "SitefinityWebApp.SfDev.Localization" -methodName "AddCulturesToSite" -parameters @($siteIndex, $culturesInput) > $null
}

function sf-localization-removeSiteCultures {
    param (
        [string[]]$cultures,
        [int]$siteIndex = 0
    )
    
    $culturesInput = _getInputFromArray $cultures
    sf-serverCode-run "SitefinityWebApp.SfDev.Localization" -methodName "RemoveCulturesFromSite" -parameters @($siteIndex, $culturesInput) > $null
}

function sf-localization-setSiteDefaultCulture {
    param (
        [string]$culture,
        [int]$siteIndex = 0
    )
    
    $culturesInput = _getInputFromArray $cultures
    sf-serverCode-run "SitefinityWebApp.SfDev.Localization" -methodName "SetSiteDefualtCulture" -parameters @($siteIndex, $culturesInput) > $null
}

function _getInputFromArray {
    param (
        [string[]]$array
    )

    $result = ""
    $array | % { $result += "$_," }
    $result.TrimEnd(',')
}