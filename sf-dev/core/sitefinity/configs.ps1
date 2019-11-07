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
function conf-setStorageMode {
    
    Param (
        [string]$storageMode,
        [string]$restrictionLevel
    )

    $context = proj-getCurrent

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
function conf-getStorageMode {
    
    Param()

    $context = proj-getCurrent

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
function conf-getFromDb {
    
    Param(
        [Parameter(Mandatory = $true)]$configName,
        $filePath = "${Env:userprofile}\Desktop\dbExport.xml"
    )

    $dbName = db-getNameFromDataConfig
    
    $config = sql-get-items -dbName $dbName -tableName 'sf_xml_config_items' -selectFilter 'dta' -whereFilter "path='${configName}.config'"

    if ($null -ne $config -and $config -ne '') {
        if (!(Test-Path $filePath)) {
            New-Item -ItemType file -Path $filePath
        }

        $doc = [xml]$config.dta
        $doc.Save($filePath) > $null
    }
    else {
        Write-Information 'Config not found in db'
    }
}

<#
    .SYNOPSIS 
    Deletes the given config contents only from the database. Same config in file system is preserved
    .PARAMETER configName
    The sitefinity config name withouth extension
#>
function conf-clearInDb {
    
    Param(
        [Parameter(Mandatory = $true)]$configName
    )

    $dbName = db-getNameFromDataConfig
    $table = 'sf_xml_config_items'
    $value = "dta = '<${configName}/>'"
    $where = "path='${configName}.config'"
    
    sql-update-items -dbName $dbName -whereFilter $where -tableName $table -value $value
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
function conf-setInDb {
    
    Param(
        [Parameter(Mandatory = $true)]$configName,
        $filePath = "${Env:userprofile}\Desktop\dbImport.xml"
    )

    $dbName = db-getNameFromDataConfig
    $table = 'sf_xml_config_items'
    $xmlString = Get-Content $filePath -Raw
    $value = "dta='$xmlString'"
    $where = "path='${configName}.config'"
    
    sql-update-items -dbName $dbName -tableName $table -whereFilter $where -value $value
}

function config-removeStartupConfig {
    $context = proj-getCurrent
    $configPath = "$($context.webAppPath)\App_Data\Sitefinity\Configuration\StartupConfig.config"
    Remove-Item -Path $configPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
    if ($ProcessError) {
        throw $ProcessError
    }
}

function config-createStartupConfig {
    param(
        [string]$user = $GLOBAL:Sf.Config.sitefinityUser,
        [Parameter(Mandatory = $true)][string]$dbName,
        [string]$password = $GLOBAL:Sf.Config.sitefinityPassword,
        [string]$sqlUser = $GLOBAL:Sf.Config.sqlUser,
        [string]$sqlPass = $GLOBAL:Sf.Config.sqlPass
    )

    $context = proj-getCurrent
    $webAppPath = $context.webAppPath
    
    Write-Information "Creating StartupConfig..."
    try {
        $appConfigPath = "${webAppPath}\App_Data\Sitefinity\Configuration"
        if (-not (Test-Path $appConfigPath)) {
            New-Item $appConfigPath -type directory > $null
        }

        $configPath = "${appConfigPath}\StartupConfig.config"

        if (Test-Path -Path $configPath) {
            Remove-Item $configPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            if ($ProcessError) {
                throw "Could not remove old StartupConfig $ProcessError"
            }
        }
        
        if ((sql-test-isDbNameDuplicate -dbName $dbName) -or [string]::IsNullOrEmpty($dbName)) {
            throw "Error creating startup.config. Database with name $dbName already exists."
        }

        $username = $user.split('@')[0]

        $XmlWriter = New-Object System.XMl.XmlTextWriter($configPath, $Null)
        $xmlWriter.WriteStartDocument()
        $xmlWriter.WriteStartElement("startupConfig")
        $XmlWriter.WriteAttributeString("username", $user)
        $XmlWriter.WriteAttributeString("password", $password)
        $XmlWriter.WriteAttributeString("enabled", "True")
        $XmlWriter.WriteAttributeString("initialized", "False")
        $XmlWriter.WriteAttributeString("email", $user)
        $XmlWriter.WriteAttributeString("firstName", $username)
        $XmlWriter.WriteAttributeString("lastName", $username)
        $XmlWriter.WriteAttributeString("dbName", $dbName)
        $XmlWriter.WriteAttributeString("dbType", "SqlServer")
        $XmlWriter.WriteAttributeString("sqlInstance", $GLOBAL:Sf.config.sqlServerInstance)
        $XmlWriter.WriteAttributeString("sqlAuthUserName", $sqlUser)
        $XmlWriter.WriteAttributeString("sqlAuthUserPassword", $sqlPass)
        $xmlWriter.WriteEndElement()
        $xmlWriter.Finalize
        $xmlWriter.Flush()
        $xmlWriter.Close() > $null
    }
    catch {
        throw "Error creating startupConfig. Message: $_"
    }
}
