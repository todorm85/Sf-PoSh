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
function sf-set-storageMode {
    [CmdletBinding()]
    Param (
        [string]$storageMode,
        [string]$restrictionLevel
    )

    $context = sf-get-currentProject

    if ($storageMode -eq '') {
        do {
            $repeat = $false
            $storageMode = Read-Host -Prompt 'Storage Mode: [f]ileSystem [d]atabase [a]uto'
            switch ($storageMode) {
                'f' { $storageMode = 'FileSystem' }
                'd' { $storageMode = 'Database' }
                'a' { $storageMode = 'Auto' }
                default { $repeat = $true }
            }
        } while ($repeat)
    }

    if ($restrictionLevel -eq '' -and $storageMode.ToLower() -eq 'auto') {
        do {
            $repeat = $false
            $restrictionLevel = Read-Host -Prompt 'Restriction level: [d]efault [r]eadonlyConfigFile'
            switch ($restrictionLevel) {
                'd' { $restrictionLevel = 'Default' }
                'r' { $restrictionLevel = 'ReadOnlyConfigFile' }
                default { $repeat = $true }
            }
        } while ($repeat)
    }

    $webConfigPath = $context.webAppPath + '\web.config'
    # set web.config readonly off
    attrib -r $webConfigPath

    $webConfig = New-Object XML
    $webConfig.Load($webConfigPath) > $null

    $telerikHandlerGroup = $webConfig.SelectSingleNode('//configuration/configSections/sectionGroup[@name="telerik"]')
    if ($telerikHandlerGroup -eq $null -or $telerikHandlerGroup -eq '') {

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
    if ($sitefinityConfig -eq $null) {
        $telerik = $webConfig.SelectSingleNode('/configuration/telerik')
        if ($telerik -eq $null) {
            $telerik = $webConfig.CreateElement("telerik")
            $webConfig.configuration.AppendChild($telerik)
        }

        $sitefinity = $webConfig.SelectSingleNode('/configuration/telerik/sitefinity')
        if ($sitefinity -eq $null) {
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
function sf-get-storageMode {
    [CmdletBinding()]
    Param()

    $context = sf-get-currentProject

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
    if ($sitefinityConfig -eq $null) {
        $storageMode = "FileSystem"
        $restrictionLevel = "Default"
    }
    else {
        $storageMode = $sitefinityConfig.storageMode
        $restrictionLevel = $sitefinityConfig.restrictionLevel

        if ($restrictionLevel -eq $null) {
            $restrictionLevel = "Default"
        }
    }

    return New-Object psobject -property  @{StorageMode = $storageMode; RestrictionLevel = $restrictionLevel }
}

<#
    .SYNOPSIS
    Extracts the sitefinity config contents from the database, formats it and saves it to desktop by default.
    .PARAMETER configName
    The name of the sitefinity config without extension
    .PARAMETER filePath
    The path to the file where the config contents will be saved. By default:"${Env:userprofile}\Desktop\dbExport.xml" 
    .OUTPUTS
    None
#>
function sf-get-configContentFromDb {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]$configName,
        $filePath = "${Env:userprofile}\Desktop\dbExport.xml"
    )

    $dbName = sf-get-appDbName
    
    $config = $tokoAdmin.sql.GetItems($dbName, 'sf_xml_config_items', "path='${configName}.config'", 'dta')

    if ($null -ne $config -and $config -ne '') {
        if (!(Test-Path $filePath)) {
            New-Item -ItemType file -Path $filePath
        }

        $doc = [xml]$config.dta
        $doc.Save($filePath) > $null
    }
    else {
        Write-Warning 'Config not found in db'
    }
}

<#
    .SYNOPSIS 
    Deletes the given config contents only from the database. Same config in file system is preserved
    .PARAMETER configName
    The sitefinity config name withouth extension
#>
function sf-clear-configContentInDb {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]$configName
    )

    $dbName = sf-get-appDbName
    $table = 'sf_xml_config_items'
    $value = "dta = '<${configName}/>'"
    $where = "path='${configName}.config'"
    
    $tokoAdmin.sql.UpdateItems($dbName, $table, $where, $value)
}

<#
    .SYNOPSIS
    Inserts config content into database. 
    .DESCRIPTION
    Inserts the sitefinity config content from given path to the database.
    .PARAMETER configName
    Name of sitefinity config without extension that will be overriden in database with content from given file on the fs.
    .PARAMETER filePath
    The source file path whose content will be inserted to the databse. Default: $filePath="${Env:userprofile}\Desktop\dbImport.xml"
    .OUTPUTS
    None
#>
function sf-insert-configContentInDb {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]$configName,
        $filePath = "${Env:userprofile}\Desktop\dbImport.xml"
    )

    $dbName = sf-get-appDbName
    $table = 'sf_xml_config_items'
    $xmlString = Get-Content $filePath -Raw
    $value = "dta='$xmlString'"
    $where = "path='${configName}.config'"

    
    $tokoAdmin.sql.UpdateItems($dbName, $table, $where, $value)
}
