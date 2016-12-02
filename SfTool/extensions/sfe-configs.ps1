if (-not $sfToolLoaded) {
    . "${PSScriptRoot}\..\sfTool.ps1"
}

function sf-set-storageMode {
    Param (
        [string]$storageMode,
        [string]$restrictionLevel
        )

    $context = _sf-get-context

    if ($storageMode -eq '') {
        do {
            $repeat = $false
            $storageMode = Read-Host -Prompt 'Storage Mode: [f]ileSystem [d]atabase [a]uto'
            switch ($storageMode)
            {
                'f' {$storageMode = 'FileSystem'}
                'd' {$storageMode = 'Database'}
                'a' {$storageMode = 'Auto'}
                default {$repeat = $true}
            }
        } while ($repeat)
    }

    if ($restrictionLevel -eq '' -and $storageMode.ToLower() -eq 'auto') {
        do {
            $repeat = $false
            $restrictionLevel = Read-Host -Prompt 'Restriction level: [d]efault [r]eadonlyConfigFile'
            switch ($restrictionLevel)
            {
                'd' {$restrictionLevel = 'Default'}
                'r' {$restrictionLevel = 'ReadOnlyConfigFile'}
                default {$repeat = $true}
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
    if ($sitefinityConfig -eq $null)
    {
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
    } else {
        $sitefinityConfig.RemoveAttribute("restrictionLevel")
    }

    $webConfig.Save($webConfigPath) > $null
}

function sf-get-storageMode {
    $context = _sf-get-context

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
    if ($sitefinityConfig -eq $null)
    {
        $storageMode = "FileSystem"
        $restrictionLevel = "Default"
    } else {
        $storageMode = $sitefinityConfig.storageMode
        $restrictionLevel = $sitefinityConfig.restrictionLevel

        if ($restrictionLevel -eq $null) {
            $restrictionLevel = "Default"
        }
    }

    return New-Object psobject -property  @{StorageMode = $storageMode; RestrictionLevel = $restrictionLevel}
}

function sf-get-configContentFromDb {
    Param(
        [Parameter(Mandatory=$true)]$configName,
        $filePath="${Env:userprofile}\Desktop\dbExport.xml"
        )

    $context = _sf-get-context
    $config = sql-get-items -dbName $context.dbName -tableName 'sf_xml_config_items' -selectFilter 'dta' -whereFilter "path='${configName}.config'"

    if ($null -ne $config -and $config -ne '') {
        if (!(Test-Path $filePath)) {
            New-Item -ItemType file -Path $filePath
        }

        $doc = [xml]$config.dta
        $doc.Save($filePath) > $null
    } else {
        Write-Warning 'Config not found in db'
    }
}

function sf-clear-configContentInDb {
    Param(
        [Parameter(Mandatory=$true)]$configName
        )

    $context = _sf-get-context
    sql-update-items -dbName $context.dbName -tableName 'sf_xml_config_items' -value "<${configName}/>" -whereFilter "path='${configName}.config'"
}

function sf-insert-configContentInDb {
    Param(
        [Parameter(Mandatory=$true)]$configName,
        $filePath="${Env:userprofile}\Desktop\dbImport.xml"
        )

    $context = _sf-get-context
    $xmlString = Get-Content $filePath -Raw

    $config = sql-update-items -dbName $context.dbName -tableName 'sf_xml_config_items' -value $xmlString -whereFilter "path='${configName}.config'"
}
