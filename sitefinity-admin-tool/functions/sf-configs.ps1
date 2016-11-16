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
        $filePath="${Env:userprofile}\Desktop\dbConfig.xml"
        )

    $context = _sf-get-context
    $config = sql-get-items -dbName $context.dbName -tableName 'sf_xml_config_items' -selectFilter 'dta' -whereFilter "path='${configName}.config'"

    if ($config -ne $null -and $config -ne '') {
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

function _sf-delete-startupConfig {
    $context = _sf-get-context
    $configPath = "$($context.webAppPath)\App_Data\Sitefinity\Configuration\StartupConfig.config"
    Remove-Item -Path $configPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
    if ($ProcessError) {
        throw $ProcessError
    }
}

function _sf-create-startupConfig {
    $context = _sf-get-context
    $webAppPath = $context.webAppPath
    
    Write-Host "Creating StartupConfig..."
    try {
        $appConfigPath = "${webAppPath}\App_Data\Sitefinity\Configuration"
        if (-not (Test-Path $appConfigPath)) {
            New-Item $appConfigPath -type directory > $null
        }

        $configPath = "${appConfigPath}\StartupConfig.config"

        if(Test-Path -Path $configPath){
            Remove-Item $configPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            if ($ProcessError) {
                throw "Could not remove old StartupConfig $ProcessError"
            }
        }

        $XmlWriter = New-Object System.XMl.XmlTextWriter($configPath,$Null)
        $xmlWriter.WriteStartDocument()
            $xmlWriter.WriteStartElement("startupConfig")
                $XmlWriter.WriteAttributeString("dbName", $context.dbName)
                $XmlWriter.WriteAttributeString("username", "admin")
                $XmlWriter.WriteAttributeString("password", "admin@2")
                $XmlWriter.WriteAttributeString("enabled", "True")
                $XmlWriter.WriteAttributeString("initialized", "False")
                $XmlWriter.WriteAttributeString("email", "admin@adminov.com")
                $XmlWriter.WriteAttributeString("firstName", "Admin")
                $XmlWriter.WriteAttributeString("lastName", "Adminov")
                $XmlWriter.WriteAttributeString("dbType", "SqlServer")
                $XmlWriter.WriteAttributeString("sqlInstance", $sqlServerInstance)
            $xmlWriter.WriteEndElement()
        $xmlWriter.Finalize
        $xmlWriter.Flush()
        $xmlWriter.Close() > $null
    } catch {
        throw "Error creating startupConfig. Message: $_.Exception.Message"
    }
}
