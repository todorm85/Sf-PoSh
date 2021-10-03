function sf-config-Web-setMachineKey {
    Param(
        $decryption = "AES",
        $decryptionKey = "53847BC18AFFC19E5C1AC792A4733216DAEB54215529A854",
        $validationKey = "DC38A2532B063784F23AEDBE821F733625AD1C05D4718D2E0D55D842DAC207FB8492043E2EE5861BB3C4B0C4742CF73BDA586A70BDDC4FD50209B465A6DBBB3D"
    )

    [XML]$xmlDoc = sf-config-open "web"
    $machineKey = xml-getOrCreateElementPath $xmlDoc.configuration "//system.web/machineKey"
    $machineKey.SetAttribute("decryption", $decryption)
    $machineKey.SetAttribute("decryptionKey", $decryptionKey)
    $machineKey.SetAttribute("validationKey", $validationKey)
    sf-config-save $xmlDoc
}

function sf-config-Web-removeMachineKey {
    [XML]$xmlDoc = sf-config-open "web"
    $systemWeb = $xmlDoc.Configuration["system.web"]
    $machineKey = $systemWeb.machineKey
    if ($machineKey) {
        $systemWeb.RemoveChild($machineKey) > $null
    }

    sf-config-save -config $xmlDoc
}

<#
    .SYNOPSIS 
    Sets the config storage mode of selected sitefinity
    .DESCRIPTION
    If no parameters are passed user is prompted to choose from available
    .PARAMETER storageMode
    The storage mode given as string.
    .PARAMETER restrictionLevel
    The restirction level if storage mode is set to "auto", otherwise it is discarded.
    .OUTPUTS
    None
#>
function sf-config-Web-setStorageMode {
    
    Param (
        [ValidateSet("Auto", "Database", "FileSystem")]
        [string]$storageMode,
        [ValidateSet("Default", "ReadOnlyConfigFile")]
        [string]$restrictionLevel
    )

    $context = sf-PSproject-get
    $webConfigPath = $context.webAppPath + '\web.config'
    # set web.config readonly off
    attrib -r $webConfigPath

    $webConfig = New-Object XML
    $webConfig.Load($webConfigPath) > $null

    $telerikHandlerGroup = $webConfig.SelectSingleNode('//configuration/configSections/sectionGroup[@name="telerik"]')
    if ($null -eq $telerikHandlerGroup -or $telerikHandlerGroup -eq '') {

        $telerikHandlerGroup = $webConfig.CreateElement("sectionGroup")
        $telerikHandlerGroup.SetAttribute('name', 'telerik')

        $telerikHandler = $webConfig.CreateElement("section")
        $telerikHandler.SetAttribute('name', 'sitefinity')
        $telerikHandler.SetAttribute('type', 'Telerik.Sitefinity.Configuration.SectionHandler, Telerik.Sitefinity')
        $telerikHandler.SetAttribute('requirePermission', 'false')

        $telerikHandlerGroup.AppendChild($telerikHandler)
        $webConfig.configuration.configSections.AppendChild($telerikHandlerGroup)
    }

    $sitefinityConfig = $webConfig.SelectSingleNode('/configuration/telerik/sitefinity/sitefinityConfig')
    if ($null -eq $sitefinityConfig) {
        $telerik = $webConfig.SelectSingleNode('/configuration/telerik')
        if ($null -eq $telerik) {
            $telerik = $webConfig.CreateElement("telerik")
            $webConfig.configuration.AppendChild($telerik)
        }

        $sitefinity = $webConfig.SelectSingleNode('/configuration/telerik/sitefinity')
        if ($null -eq $sitefinity) {
            $sitefinity = $webConfig.CreateElement("sitefinity")
            $telerik.AppendChild($sitefinity)
        }

        $sitefinityConfig = $webConfig.CreateElement("sitefinityConfig")

        $sitefinity.AppendChild($sitefinityConfig)
    }

    $sitefinityConfig.SetAttribute("storageMode", $storageMode)
    if ($restrictionLevel -ne $null -and $restrictionLevel -ne "") {
        $sitefinityConfig.SetAttribute("restrictionLevel", $restrictionLevel)
    }
    else {
        $sitefinityConfig.RemoveAttribute("restrictionLevel")
    }

    $webConfig.Save($webConfigPath) > $null
}

<#
    .SYNOPSIS 
    Returns config storage mode info object for selected sitefinity
    .OUTPUTS
    psobject -property  @{StorageMode = $storageMode; RestrictionLevel = $restrictionLevel}
#>

function sf-config-Web-getStorageMode {
    
    Param()

    $context = sf-PSproject-get

    # set web.config readonly off
    $webConfigPath = $context.webAppPath + '\web.config'
    attrib -r $webConfigPath

    $webConfig = New-Object XML
    try {
        $webConfig.Load($webConfigPath)
    }
    catch {
        throw "Error loading web.config. Invalid path."
    }

    $sitefinityConfig = $webConfig.SelectSingleNode('/configuration/telerik/sitefinity/sitefinityConfig')
    if ($null -eq $sitefinityConfig) {
        $storageMode = "FileSystem"
        $restrictionLevel = "Default"
    }
    else {
        $storageMode = $sitefinityConfig.storageMode
        $restrictionLevel = $sitefinityConfig.restrictionLevel

        if ($null -eq $restrictionLevel) {
            $restrictionLevel = "Default"
        }
    }

    return New-Object psobject -property  @{StorageMode = $storageMode; RestrictionLevel = $restrictionLevel }
}