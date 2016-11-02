# Usings
. "${PSScriptRoot}\sf-constants.ps1"
. "${PSScriptRoot}\common\iis.ps1"
. "${PSScriptRoot}\common\sql.ps1" $sqlServerInstance
. "${PSScriptRoot}\common\os.ps1"
. "${PSScriptRoot}\common\tfs.ps1" $tfPath
Import-Module "WebAdministration"

#region PUBLIC

# Sitefinity instances management

function sf-create-sitefinity {
    Param(
        [string]$name,
        [string]$branch = $defaultBranch,
        [switch]$startWebApp,
        [switch]$buildSolution
        )

    $defaultContext = _sfData-get-defaultContext $name
    try {
        $newContext = @{ name = $defaultContext.name }
        $newContext.displayName = $defaultContext.displayName
        if (Test-Path $defaultContext.solutionPath) {
            throw "Path already exists:" + $defaultContext.solutionPath
        }

        Write-Host "Creating solution path..."
        New-Item $defaultContext.solutionPath -type directory > $null
        $newContext.solutionPath = $defaultContext.solutionPath;

        # create and map workspace
        Write-Host "Creating workspace..."
        $workspaceName = $defaultContext.displayName
        tfs-create-workspace $workspaceName $defaultContext.solutionPath

        Write-Host "Creating workspace mappings..."
        tfs-create-mappings -branch $branch -branchMapPath $defaultContext.solutionPath -workspaceName $workspaceName

        Write-Host "Getting latest workspace changes..."
        tfs-get-latestChanges -branchMapPath $defaultContext.solutionPath

        # persist current context to script data
        $newContext.dbName = $defaultContext.dbName
        $newContext.webAppPath = $defaultContext.solutionPath + '\SitefinityWebApp'
        $oldContext = ''
        $oldContext = _sfData-get-currentContext
        _sfData-set-currentContext $newContext
        _sfData-save-context $newContext
    } catch {
        Write-Host "############ CLEANING UP ############"
        Set-Location $PSScriptRoot
        if ($newContext.solutionPath -ne '' -and $newContext.solutionPath -ne $null) {
            Remove-Item -Path $newContext.solutionPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            if ($ProcessError) {
                Write-Host $ProcessError
            }
        }

        if ($oldContext -ne '') {
            _sfData-set-currentContext $oldContext
        }

        throw "Nothing created. Try again. Error: $_.Exception.Message"
    }

    try {
        if ($buildSolution) {
            Write-Host "Building solution..."
            sf-build-solution
        }
    } catch {
        $startWebApp = $false
        Write-Warning "SOLUTION WAS NOT BUILT. Message: $_.Exception.Message"
    }

    try {
        Write-Host "Creating website..."
        _sf-create-website -newWebsiteName $defaultContext.websiteName -newPort $defaultContext.port -newAppPool $defaultContext.appPool
    } catch {
        $startWebApp = $false
        Write-Warning "WEBSITE WAS NOT CREATED. Message: $_.Exception.Message"
    }

    if ($startWebApp) {
        try {
            Write-Host "Initializing Sitefinity"
            _sf-create-startupConfig
            _sf-start-sitefinity
        } catch {
            Write-Warning "APP WAS NOT INITIALIZED. $_.Exception.Message"
            _sf-delete-startupConfig
        }
    }

    # Display message
    os-popup-notification "Operation completed!"
}

function sf-import-sitefinity {
    Param(
        [Parameter(Mandatory=$true)][string]$displayName,
        [Parameter(Mandatory=$true)][string]$path
        )

    if (!(Test-Path $path)) {
        throw "Invalid path"
    }

    $isSolution = Test-Path "$path\Telerik.Sitefinity.sln"
    $isWebApp = Test-Path "$path\web.config"
    if (-not $isWebApp -and -not $isSolution) {
        throw "No web app or solution found."
    }

    if ($isWebApp -and $isSolution) {
        throw "Cannot determine whether webapp or solution."
    }

    $defaultContext = _sfData-get-defaultContext $displayName
    $newContext = @{ name = $defaultContext.name }
    $newContext.displayName = $defaultContext.displayName
    if ($isSolution) {
        $newContext.solutionPath = $path
        $newContext.webAppPath = $path + '\SitefinityWebApp'
    } else {
        $newContext.solutionPath = ''
        $newContext.webAppPath = $path
    }

    while ($appInitialized -ne 'y' -and $appInitialized -ne 'n') {
        $appInitialized = Read-Host -Prompt 'Is your app initialized with a database? [y/n]'
    }

    if ($appInitialized -eq 'y') {
        $isDuplicate = $false
        while (!$isDuplicate) {
            $dbName = Read-Host -Prompt 'Enter database name: '
            $isDuplicate = sql-test-isDbNameDuplicate $dbName
        }

        $newContext.dbName = $dbName
    } else {
        $newContext.dbName = $defaultContext.dbName
    }

    while ($hasWebSite -ne 'y' -and $hasWebSite -ne 'n') {
        $hasWebSite = Read-Host -Prompt 'Does your app has a website created for it? [y/n]'
    }

    if ($hasWebSite -eq 'y') {
        $isDuplicate = $false
        while (!$isDuplicate) {
            $websiteName = Read-Host -Prompt 'Enter website name: '
            $isDuplicate = sql-test-isDbNameDuplicate $dbName
            $newContext.websiteName = $websiteName
        }
    } else {
        try {
            Write-Host "Creating website..."
            _sfData-set-currentContext $newContext
            _sf-create-website -newWebsiteName $defaultContext.websiteName -newPort $defaultContext.port -newAppPool $defaultContext.appPool
        } catch {
            $startWebApp = $false
            Write-Warning "WEBSITE WAS NOT CREATED. Message: $_.Exception.Message"
        }
    }

    _sfData-set-currentContext $newContext
    _sfData-save-context $newContext

    # Display message
    os-popup-notification "Operation completed!"
}

function sf-show-sitefinities {
    $sitefinities = @(_sfData-get-allContexts)
    if ($sitefinities[0] -eq $null) {
        Write-Host "No sitefinities! Create one first. sf-create-sitefinity or manually add in sf-data.xml"
        return
    }

    foreach ($sitefinity in $sitefinities) {
        _sf-show-sitefinity $sitefinity
    }
}

function sf-show-selectedSitefinity {
    $context = _sf-get-context

    _sf-show-sitefinity $context
}

function sf-delete-sitefinity {
    Param(
        [switch]$keepWorkspace,
        [switch]$keepProjectFiles
        )
    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    $workspaceName = tfs-get-workspaceName $context.webAppPath
    $dbName = $context.dbName
    $websiteName = $context.websiteName

    # while ($true) {
    #     $isConfirmed = Read-Host -Prompt "WARNING! Current operation will reset IIS. You also need to have closed the current sitefinity solution in Visual Studio and any opened browsers for complete deletion. Continue [y/n]?"
    #     if ($isConfirmed -eq 'y') {
    #         break;
    #     }

    #     if ($isConfirmed -eq 'n') {
    #         return
    #     }
    # }

    Set-Location -Path $PSScriptRoot

    # Del workspace
    if ($workspaceName -ne '' -and !($keepWorkspace)) {
        Write-Host "Deleting workspace..."
        try {
            tfs-delete-workspace $workspaceName
        } catch {
            Write-Host "Could not delete workspace $_.Exception.Message"
        }
    }

    # Del db
    Write-Host "Deleting sitefinity database..."
    if ($dbName -ne '') {
        try {
            sql-delete-database -dbName $dbName
        } catch {
            Write-Host "Could not delete database: ${dbName}. $_.Exception.Message"
        }
    }

    # Del Website
    Write-Host "Deleting website..."
    if ($websiteName -ne '') {
        try {
            _sf-delete-website
        } catch {
            Write-Host "Could not delete website ${websiteName}. $_.Exception.Message"
        }
    }

    # Del dir
    if (!($keepProjectFiles)) {
        Write-Host "Resetting IIS and deleting solution directory..."
        try {
            iisreset.exe > $null
            if ($solutionPath -ne "") {
                Remove-Item $solutionPath -recurse -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            } else {
                Remove-Item $context.webAppPath -recurse -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            }

            if ($ProcessError) {
                throw $ProcessError
            }
        } catch {
            Write-Host "Errors deleting sitefinity directory. $_.Exception.Message"
        }
    }

    Write-Host "Deleting data entry..."
    _sfData-delete-context $context
    _sfData-set-currentContext $null

    # Display message
    os-popup-notification -msg "Operation completed!"

    sf-select-sitefinity
}

function sf-select-sitefinity {
    $sitefinities = @(_sfData-get-allContexts)
    if ($sitefinities[0] -eq $null) {
        Write-Host "No sitefinities! Create one first. sf-create-sitefinity or manually add in sf-data.xml"
        return
    }

    foreach ($sitefinity in $sitefinities) {
        $index = [array]::IndexOf($sitefinities, $sitefinity)
        Write-Host  $index : $sitefinity.displayName
    }

    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose sitefinity'
        $selectedSitefinity = $sitefinities[$choice]
        if ($selectedSitefinity -ne $null) {
            break;
        }
    }

    _sfData-set-currentContext $selectedSitefinity
    Set-Location $selectedSitefinity.webAppPath
}

function sf-rename-sitefinity {
    Param([string]$newName)

    $context = _sf-get-context

    if ([string]::IsNullOrEmpty($newName)) {
        $newName = $context.name
    }

    $context.displayName = $newName
    $workspaceName = tfs-get-workspaceName $context.webAppPath
    if ($workspaceName -ne "") {
        & $tfPath workspace /newname:$newName $workspaceName /noprompt
        $workspaceName = $newName
    }
    
    _sfData-save-context $context
}

# Sitefinity web app management

function sf-reset-sitefinityWebApp {
    Param(
        [switch]$start,
        [switch]$configRestrictionSafe,
        [switch]$rebuild,
        [switch]$build
        )

    if ($rebuild) {
        sf-rebuild-solution
    }

    if ($build) {
        sf-build-solution
    }

    $context = _sf-get-context
    # Write-Host "Restarting app pool..."
    # Restart-WebItem ("IIS:\AppPools\" + $appPool)
    # iisreset.exe

    Write-Host "Deleting App_Data files..."
    try {
        _sf-delete-appDataFiles
    } catch {
        Write-Warning "Errors ocurred while deleting App_Data files. Usually .log files cannot be deleted because they are left locked by iis processes. While this does not prevent sitefinity from restarting you should keep in mind that the log files may contain polluted entries from previous runs. `nError Message: `n $_.Exception.Message"
    }

    Write-Host "Deleting database..."
    try {
        sql-delete-database -dbName $context.dbName
    } catch {
        Write-Warning "Erros while deleting database: $_.Exception.Message"
    }

    try {
        _sf-create-startupConfig
    } catch {
        throw "Erros while creating startupConfig: $_.Exception.Message"
    }
    
    sf-reset-webSiteApp

    if ($start) {
        Start-Sleep -s 2
        try {
            if ($configRestrictionSafe) {
                # set readonly off
                $oldConfigStroageSettings = sf-get-storageMode
                if ($oldConfigStroageSettings -ne $null -and $oldConfigStroageSettings -ne '') {
                    sf-set-storageMode -storageMode $oldConfigStroageSettings.StorageMode -restrictionLevel "Default"
                }
            }

            $port = @(iis-get-websitePort $context.websiteName)[0]
            _sf-start-sitefinity -url "http://localhost:$($port)"
        } catch {
            Write-Host "`n`n"
            Write-Warning "ERROS WHILE INITIALIZING WEB APP. MOST LIKELY CAUSE: YOU MUST LOG OFF FROM THE WEBAPP INSTANCE IN THE BROWSER WHEN REINITIALIZING SITEFINITY INSTANCE OTHERWISE 'DUPLICATE KEY ERRORS' AND OTHER VARIOUS OPENACCESS EXCEPTIONS OCCUR WHEN USING STARTUPCONFIG`n"

            _sf-delete-startupConfig

            $choice = Read-Host "Display stack trace? [y/n]"
            while($true) {
                if ($choice -eq 'y') {
                    Write-Host "`n`nException: $_.Exception"
                    break
                }

                if ($choice -eq 'n') {
                    break
                }

                $choice = Read-Host "Display stack trace? [y/n]"
            }
        }  finally {
            # restore readonly state
            if ($configRestrictionSafe) {
                if ($oldConfigStroageSettings -ne $null -and $oldConfigStroageSettings -ne '') {
                   sf-set-storageMode -storageMode $oldConfigStroageSettings.StorageMode -restrictionLevel $oldConfigStroageSettings.RestrictionLevel
                }
            }
        }
    }

    # display message
    os-popup-notification -msg "Operation completed!"
}

function sf-add-precompiledTemplates {
    $context = _sf-get-context
    $webAppPath = $context.webAppPath

    & $sitefinityCompiler /appdir="${webAppPath}" /username="" /password="" /strategy="Backend" /membershipprovider="Default" /templateStrategy="Default"
}

function sf-remove-precompiledTemplates {
    $context = _sf-get-context
    $webAppPath = $context.webAppPath

    $dlls = Get-ChildItem -Force "${webAppPath}\bin" | Where-Object { ($_.PSIsContainer -eq $false) -and (( $_.Name -like "Telerik.Sitefinity.PrecompiledTemplates.dll") -or ($_.Name -like "Telerik.Sitefinity.PrecompiledPages.Backend.0.dll")) }
    try {
        os-del-filesAndDirsRecursive $dlls
    } catch {
        throw "Item could not be deleted: $dll.PSPath`nMessage:$_.Exception.Message"
    }
}

#Solution

function sf-get-latest {
    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

    if ($solutionPath -eq '') {
        throw "Solution path is not set."
    }

    Write-Host "Getting latest changes for path ${solutionPath}."
    tfs-get-latestChanges -branchMapPath $solutionPath
    Write-Host "Getting latest changes complete."
}

function sf-undo-pendingChanges {
    $context = _sf-get-context
    if (!(Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }

    tfs-undo-pendingChanges $context.solutionPath
}

function sf-show-pendingChanges {
    Param(
        [switch]$detailed
        )

    if ($detailed) {
        $format = "Detailed"
    } else {
        $format = "Brief"
    }

    $context = _sf-get-context
    $workspaceName = tfs-get-workspaceName $context.webAppPath
    & tf.exe stat /workspace:$workspaceName /format:$($format)
}

function sf-open-solution {
    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    if ($solutionPath -eq '') {
        throw "invalid or no solution path"
    }

    & $vsPath "${solutionPath}\telerik.sitefinity.sln"
}

function sf-build-solution {
    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

    Write-Host "Building solution ${solutionPath}\Telerik.Sitefinity.sln"
    $output = & $msBUildPath /verbosity:quiet /nologo "${solutionPath}\Telerik.Sitefinity.sln" 2>&1
    if ($LastExitCode -ne 0)
    {
        throw "$output"
    }
}

function sf-rebuild-solution {
    Write-Host "Rebuilding solution..."
    try {
        _sf-clean-solution
    } catch {
        Write-Warning "Errors while cleaning solution: $_.Exception.Message"
    }

    sf-build-solution
}

# Configs

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

# DBP

function sf-install-dbp {

    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

    & "${solutionPath}\Builds\DBPModuleSetup\dbp.ps1" -organizationAccountId $dbpAccountId -port $dbpPort -environment $dbpEnv
}

function sf-uninstall-dbp {

    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

    & "${solutionPath}\Builds\DBPModuleSetup\dbp.ps1"  -organizationAccountId $dbpAccountId -port $dbpPort -environment $dbpEnv -rollback $true
}

# IIS

function sf-browse-webSite {
    Param([switch]$newBrowser)

    $context = _sf-get-context
    $port = @(iis-get-websitePort $context.websiteName)[0]
    if ($port -eq '' -or $port -eq $null) {
        throw "No sitefinity port set."
    }

    if ($newBrowser) {
        & start $browserPath
    }

    & $browserPath "http://localhost:${port}/Sitefinity" -noframemerging
}

function sf-reset-webSiteApp {
    Param([switch]$start)

    $context = _sf-get-context

    $binPath = "$($context.webAppPath)\bin\dummy.sf"
    New-Item -ItemType file -Path $binPath > $null
    Remove-Item -Path $binPath > $null

    if ($start) {
        Start-Sleep -s 1
        _sf-start-sitefinity
    }
}

function sf-reset-appPool {
    Param([switch]$start)

    $context = _sf-get-context
    $appPool = @(iis-get-siteAppPool $context.websiteName)
    if ($appPool -eq '') {
           throw "No app pool set."
    }

    Restart-WebItem ("IIS:\AppPools\" + $appPool)
    if ($start) {
        Start-Sleep -s 1
        _sf-start-sitefinity
    }
}

function sf-change-appPool {
    $context = _sf-get-context
    $websiteName = $context.websiteName

    if ($websiteName -eq '') {
        throw "Website name not set."
    }

    # display app pools with websites
    $appPools = @(Get-ChildItem ("IIS:\AppPools"))
    $appPools

    foreach ($pool in $appPools) {
        $index = [array]::IndexOf($appPools, $pool)
        Write-Host  $index : $pool.name
    }

    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose appPool'
        $selectedPool = $appPools[$choice]
        if ($selectedPool -ne $null) {
            break;
        }
    }

    $selectedPool
    try {
        Set-ItemProperty "IIS:\Sites\${websiteName}" -Name "applicationPool" -Value $selectedPool.name
    } catch {
        throw "Could not set website pools"
    }
}

function sf-add-sitePort {
    Param(
        [Parameter(Mandatory=$true)][string]$port
        )

    while(!(os-test-isPortFree $port) -or !(iis-test-isPortFree $port)) {
        $port = Read-Host -Prompt 'Port used. Enter new: '
    }

    $context = _sf-get-context
    $websiteName = $context.websiteName

    New-WebBinding -Name $websiteName -port $port
}

function sf-remove-sitePort {
    Param(
        [Parameter(Mandatory=$true)][string]$port
        )

    $context = _sf-get-context
    $websiteName = $context.websiteName

    Remove-WebBinding -Name $websiteName -port $port
}

# Misc

function sf-clear-nugetCache {
    $context = _sf-get-context
    if (!(Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }

    & "$($context.solutionPath)\.nuget\nuget.exe" locals all -clear
}

function sf-explore-appData {
    $context = _sf-get-context
    $webAppPath = $context.webAppPath

    cd "${webAppPath}\App_Data\Sitefinity"
}

function sf-start-webTestRunner {

    & $webTestRunner
}

function sf-copy-decModule {
    Param(
        [switch]$build,
        [switch]$revert)

    $context = _sf-get-context
    $decDllsPath = "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector\bin\Debug"
    $decProjectPath = "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector\Telerik.Sitefinity.DataIntelligenceConnector.csproj"
    
    if ($build) {
        $output = & $msBUildPath /verbosity:quiet /nologo $decProjectPath 2>&1
        if ($LastExitCode -ne 0)
        {
            throw "$output"
        }
    }
    
    Copy-Item "${decDllsPath}\Telerik.Sitefinity.DataIntelligenceConnector.dll" "$($context.webAppPath)\bin"
    Copy-Item "${decDllsPath}\Telerik.Sitefinity.DataIntelligenceConnector.pdb" "$($context.webAppPath)\bin"

    Copy-Item "${decDllsPath}\Telerik.DigitalExperienceCloud.Client.dll" "$($context.webAppPath)\bin"
    Copy-Item "${decDllsPath}\Telerik.DigitalExperienceCloud.Client.pdb" "$($context.webAppPath)\bin"

    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests.dll" "$($context.webAppPath)\bin"
    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests.pdb" "$($context.webAppPath)\bin"

    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\Telerik.Sitefinity.DataIntelligenceConnector.TestUI.Arrangements.dll" "$($context.webAppPath)\bin"
    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\Telerik.Sitefinity.DataIntelligenceConnector.TestUI.Arrangements.pdb" "$($context.webAppPath)\bin"

    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\Telerik.Sitefinity.DataIntelligenceConnector.TestUtilities.dll" "$($context.webAppPath)\bin"
    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\Telerik.Sitefinity.DataIntelligenceConnector.TestUtilities.pdb" "$($context.webAppPath)\bin"

    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\Telerik.WebTestRunner.Server.dll" "$($context.webAppPath)\bin"
    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\Telerik.WebTestRunner.Server.pdb" "$($context.webAppPath)\bin"

    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\Telerik.Sitefinity.TestArrangementService.Core.dll" "$($context.webAppPath)\bin"
    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\Telerik.Sitefinity.TestArrangementService.Core.pdb" "$($context.webAppPath)\bin"
    
    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\WebDriver.dll" "$($context.webAppPath)\bin"
    
    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\Gallio.dll" "$($context.webAppPath)\bin"
    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\Gallio40.dll" "$($context.webAppPath)\bin"
    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\MbUnit.dll" "$($context.webAppPath)\bin"
    Copy-Item "D:\DEC-Connector\data-intell-sitefinity-connector\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests\bin\Debug\MbUnit40.dll" "$($context.webAppPath)\bin"

    if ($revert) {
        Remove-Item "$($context.webAppPath)\bin\Telerik.Sitefinity.DataIntelligenceConnector.dll"
        Remove-Item "$($context.webAppPath)\bin\Telerik.Sitefinity.DataIntelligenceConnector.pdb"
        
        Remove-Item "$($context.webAppPath)\bin\Telerik.DigitalExperienceCloud.Client.dll"
        Remove-Item "$($context.webAppPath)\bin\Telerik.DigitalExperienceCloud.Client.pdb"

        Remove-Item "$($context.webAppPath)\bin\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests.dll"
        Remove-Item "$($context.webAppPath)\bin\Telerik.Sitefinity.DataIntelligenceConnector.IntegrationTests.pdb"

        Remove-Item "$($context.webAppPath)\bin\Telerik.Sitefinity.DataIntelligenceConnector.TestUI.Arrangements.dll"
        Remove-Item "$($context.webAppPath)\bin\Telerik.Sitefinity.DataIntelligenceConnector.TestUI.Arrangements.pdb"

        Remove-Item "$($context.webAppPath)\bin\Telerik.Sitefinity.DataIntelligenceConnector.TestUtilities.dll"
        Remove-Item "$($context.webAppPath)\bin\Telerik.Sitefinity.DataIntelligenceConnector.TestUtilities.pdb"

        Remove-Item "$($context.webAppPath)\bin\Telerik.WebTestRunner.Server.dll"
        Remove-Item "$($context.webAppPath)\bin\Telerik.WebTestRunner.Server.pdb"

        Remove-Item "$($context.webAppPath)\bin\Telerik.Sitefinity.TestArrangementService.Core.dll"
        Remove-Item "$($context.webAppPath)\bin\Telerik.Sitefinity.TestArrangementService.Core.pdb"
        
        Remove-Item "$($context.webAppPath)\bin\WebDriver.dll" 
        
        Remove-Item "$($context.webAppPath)\bin\Gallio.dll" 
        Remove-Item "$($context.webAppPath)\bin\Gallio40.dll" 
        Remove-Item "$($context.webAppPath)\bin\MbUnit.dll" 
        Remove-Item "$($context.webAppPath)\bin\MbUnit40.dll" 
    }

    os-popup-notification "Operation completed!"
}

#endregion

#region PRIVATE

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
                $XmlWriter.WriteAttributeString("username", $webAppUser)
                $XmlWriter.WriteAttributeString("password", $webAppUserPass)
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

function _sf-start-sitefinity {
    param(
        [string]$url,
        [Int32]$totalWaitSeconds = 10 * 60,
        [Int32]$attempts = 1
    )

    $context = _sf-get-context
    $port = @(iis-get-websitePort $context.websiteName)[0]
    if ($port -eq '' -or $port -eq $null) {
        throw "No port defined for selected sitefinity."
    } else {
        $url = "http://localhost:$($port)"
    }

    $errorMsg = "Sitefinity initialization failed!"
    $ErrorActionPreference = "SilentlyContinue"
    $attempt = 1
    while($attempt -le $attempts)
    {
        if($attempt -eq $attempts)
        {
            $ErrorActionPreference = "Stop"
        }

        $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
        $statusUrl = "$url/appstatus"

        Write-Host "Attempt[$attempt] Starting Sitefinity..."
        $retryCount = 0

        try
        {
            $retryCount++
            # Send initial request to begin bootstrapping sitefinity
            $response = Invoke-WebRequest $statusUrl -TimeoutSec 1600
            # if sitefinity bootstrapped successfully appstatus should return 200 ok and it is in initializing state
            if($response.StatusCode -eq 200)
            {
                Write-Host "Sitefinity is starting..."
            }

            while($response.StatusCode -eq 200)
            {
                Write-Host "Retry[$retryCount] Checking Sitefinity status: '$statusUrl'"
                $retryCount++

                # Checking for error status info
                $statusInfo = Invoke-RestMethod $statusUrl -TimeoutSec 1600
                $errorStatusCheck = $statusInfo.Info | Where-Object { $_.SeverityString -eq "Critical" -or $_.SeverityString -eq "Error"}
                if($errorStatusCheck)
                {
                    Write-Warning $errorMsg
                    throw $errorStatusCheck.Message
                }

                $response = Invoke-WebRequest $statusUrl -TimeoutSec 1600
                if($elapsed.Elapsed.TotalSeconds -gt $totalWaitSeconds)
                {
                    throw "Sitefinity did NOT start in the specified maximum time"
                }

                Start-Sleep -s 5
             }
        } catch {
            # if request to appstatus returned 404, sitefinity has initialized
           if($_.Exception.Response.StatusCode.Value__ -eq 404)
           {
               try {
                    $response = Invoke-WebRequest $url -TimeoutSec 1600
               } catch {
                    # do nothing
               }

               # if request to base url is 200 ok sitefinity has started
               if($response.StatusCode -eq 200)
               {
                    Write-Warning "Sitefinity has started after $($elapsed.Elapsed.TotalSeconds) second(s)"
               }

               else
               {
                    Write-Warning $errorMsg
                    throw $errorMsg
               }

            } else {
               Write-Host "Sitefinity failed to start - StatusCode: $($_.Exception.Response.StatusCode.Value__)"
               # Write-Host $_ | Format-List -Force
               # Write-Host $_.Exception | Format-List -Force
               throw $_
           }
        }

        $attempt++
        Start-Sleep -s 5
    }
}

function _sf-clean-solution {
    Write-Host "Cleaning solution..."
    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

    $errorMessage = ''
    #delete all bin, obj and packages
    Write-Host "Deleting bins and objs..."
    $dirs = Get-ChildItem -force -recurse $solutionPath | Where-Object { ($_.PSIsContainer -eq $true) -and (( $_.Name -like "bin") -or ($_.Name -like "obj")) }
    try {
        os-del-filesAndDirsRecursive $dirs
    } catch {
        $errorMessage = "Errors while deleting bins and objs:`n" + $_.Exception.Message
    }

    if ($errorMessage -ne '') {
        $errorMessage = "Errors while deleting bins and objs:`n$errorMessage"
    }

    Write-Host "Deleting packages..."
    $dirs = Get-ChildItem "${solutionPath}\packages" | Where-Object { ($_.PSIsContainer -eq $true) }
    try {
        os-del-filesAndDirsRecursive $dirs
    } catch {
        $errorMessage = "$errorMessage`nErrors while deleting packages:`n" + $_.Exception.Message
    }

    if ($errorMessage -ne '') {
        throw $errorMessage
    }
}

function _sf-delete-appDataFiles {
    Write-Host "Deleting sitefinity configs, logs, temps..."
    $context = _sf-get-context
    $webAppPath = $context.webAppPath
    $errorMessage = ''
    if (Test-Path "${webAppPath}\App_Data\Sitefinity") {
        $dirs = Get-ChildItem "${webAppPath}\App_Data\Sitefinity" | Where-Object { ($_.PSIsContainer -eq $true) -and (( $_.Name -like "Configuration") -or ($_.Name -like "Temp") -or ($_.Name -like "Logs"))}
        try {
            os-del-filesAndDirsRecursive $dirs
        } catch {
            $errorMessage = "${errorMessage}`n" + $_.Exception.Message
        }
    }

    if (Test-Path "${webAppPath}\App_Data\Telerik") {
        $files = Get-ChildItem "${webAppPath}\App_Data\Telerik" | Where-Object { ($_.PSIsContainer -eq $false) -and ($_.Name -like "sso.config") }
        try {
            os-del-filesAndDirsRecursive $files
        } catch {
            $errorMessage = "${errorMessage}`n" + $_.Exception.Message
        }
    }

    if ($errorMessage -ne '') {
        throw $errorMessage
    }
}

function _sf-get-context {
    $context = _sfData-get-currentContext
    if ($context -eq '') {
        throw "Invalid context object."
    } elseif ($context -eq $null ) {
        throw "No sitefinity selected."
    } else {
        return $context
    }
}

function _sf-create-website {
    Param(
        [string]$newWebsiteName,
        [string]$newPort,
        [string]$newAppPool
        )

    $context = _sf-get-context
    $websiteName = $context.websiteName

    if ($context.websiteName -ne '' -and $context.websiteName -ne $null) {
        throw 'Current context already has a website assigned!'
    }

    $newAppPath = $context.webAppPath
    try {
        $site = iis-create-website -newWebsiteName $newWebsiteName -newPort $newPort -newAppPath $newAppPath -newAppPool $newAppPool
        $context.websiteName = $site.name
        _sfData-save-context $context
    } catch {
        $context.websiteName = ''
        throw "Error creating site: $_.Exception.Message"
    }
}

function _sf-delete-website {
    $context = _sf-get-context
    $websiteName = $context.websiteName
    if ($websiteName -eq '') {
        throw "Website name not set."
    }

    $oldWebsiteName = $context.websiteName
    $context.websiteName = ''
    try {
        _sfData-save-context $context
        Remove-WebSite -Name $websiteName
    } catch {
        $context.websiteName = $oldWebsiteName
        _sfData-save-context $context
        throw "Error: $_.Exception.Message"
    }
}

function _sf-show-sitefinity {
    Param(
        [Parameter(Mandatory=$true)]$context
        )

    $ports = @(iis-get-websitePort $context.websiteName)
    $appPool = @(iis-get-siteAppPool $context.websiteName)
    $workspaceName = tfs-get-workspaceName $context.webAppPath
    $mapping = tfs-get-mappings $context.webAppPath

    $sitefinity = @(
        [pscustomobject]@{id = 1; Parameter = "Sitefinity name"; Value = $context.displayName;},
        [pscustomobject]@{id = 2; Parameter = "Solution path"; Value = $context.solutionPath;},
        [pscustomobject]@{id = 3; Parameter = "Web app path"; Value = $context.webAppPath;},
        [pscustomobject]@{id = 4; Parameter = "Workspace name"; Value = $workspaceName;},
        [pscustomobject]@{id = 5; Parameter = "Mapping"; Value = $mapping;},
        [pscustomobject]@{id = 6; Parameter = "Database Name"; Value = $context.dbName;},
        [pscustomobject]@{id = 7; Parameter = "Website Name in IIS"; Value = $context.websiteName;},
        [pscustomobject]@{id = 8; Parameter = "Ports"; Value = $ports;},
        [pscustomobject]@{id = 9; Parameter = "Application Pool Name"; Value = $appPool;}
    )

    $sitefinity | Sort-Object -Property id | Format-Table -Property Parameter, Value -auto
}

#endregion

#region DATA LAYER

function _sfData-validate-context {
    Param($context)

    if ($context -eq '') {
        throw "Invalid sitefinity context. Cannot be empty string."
    } elseif ($context -ne $null){
        if ($context.name -eq '') {
            throw "Invalid sitefinity context. No sitefinity name."
        }

        if ($context.solutionPath -ne '') {
            if (-not (Test-Path $context.solutionPath)) {
                throw "Invalid sitefinity context. Solution path does not exist."
            }
        }
        
        if (-not(Test-Path $context.webAppPath)) {
            throw "Invalid sitefinity context. No web app path or it does not exist."
        }
    }
}

function _sfData-get-currentContext {

    _sfData-validate-context $script:globalContext
    return $script:globalContext
}

function _sfData-set-currentContext {
    Param($newContext)

    _sfData-validate-context $newContext

    $script:globalContext = $newContext
}

function _sfData-apply-contextConventions {
    Param(
        $defaultContext
        )

    $name = $defaultContext.name
    $solutionPath = "d:\sitefinities\${name}";
    $webAppPath = "d:\sitefinities\${name}\SitefinityWebApp";
    $websiteName = $name
    $appPool = "DefaultAppPool"

    # initial port to start checking from
    $port = 1111
    while(!(os-test-isPortFree $port) -or !(iis-test-isPortFree $port)) {
        $port++
    }

    $dbName = $name
    $i = 0
    while ((sql-test-isDbNameDuplicate $dbName)) {
        $dbName = $name + '_' + $i
        $i++
    }

    $defaultContext.solutionPath = $solutionPath
    $defaultContext.webAppPath = $webAppPath
    $defaultContext.dbName = $dbName
    $defaultContext.websiteName = $websiteName
    $defaultContext.appPool = $appPool
    $defaultContext.port = $port
}

function _sfData-get-defaultContext {
    Param(
        [string]$displayName
        )

    function validateName ($name) {
        $sitefinities = @(_sfData-get-allContexts)
        foreach ($sitefinity in $sitefinities) {
            if ($sitefinity.name -eq $name) {
                return $false;
            }
        }    

        return $true;
    }

    function validateDisplayName ($name) {
        $sitefinities = @(_sfData-get-allContexts)
        foreach ($sitefinity in $sitefinities) {
            if ($sitefinity.displayName -eq $name) {
                return $false;
            }
        }    

        return $true;
    }

    # if (-not([string]::IsNullOrEmpty($displayName))) {
    #     $sitefinities = @(_sfData-get-allContexts)
    #     foreach ($sitefinity in $sitefinities) {
    #         if ($sitefinity.displayName -eq $displayName) {
    #             Write-Host "Sitefinity display name already used. ${displayName}"
    #             $displayName = Read-Host -Prompt 'Enter new sitefinity name: '
    #             _sfData-get-defaultContext $displayName
    #             return
    #         }
    #     }
    # } else {
    #     $displayName = "sitefinity"
    # }

    # set valid display name
    $i = 0;
    while($true) {
        $isValid = (validateDisplayName $displayName) -and (validateName $displayName)
        if ($isValid) {
            break;
        }

        # $i++;
        # $displayName = "${displayName}_${i}"
        $displayName = Read-Host -Prompt "Display name $displayName used. Enter new display name: "
    }

    $name = $displayName
    
    # build default context object
    $defaultContext = @{
        displayName = $displayName;
        name = $name;
        solutionPath = '';
        webAppPath = '';
        dbName = '';
        websiteName = '';
        port = '';
        appPool = '';
    }

    # check sitefinity name
    while($true) {
        if ($name -notmatch "^[a-zA-Z]+\w*$") {
           Write-Host "Sitefinity name must contain only alphanumerics and not start with number."
           $name = Read-Host "Enter new name: "
        } else {
            $defaultContext.name = $name
            break
        }
    }

    _sfData-apply-contextConventions $defaultContext

    return $defaultContext
}

function _sfData-get-allContexts {
    $data = New-Object XML
    $data.Load($dataPath)
    return $data.data.sitefinities.sitefinity
}

function _sfData-delete-context {
    Param($context)
    Write-Host "Updating script databse..."
    $name = $context.name
    try {
        $data = New-Object XML
        $data.Load($dataPath)
        $sitefinities = $data.data.sitefinities.sitefinity
        ForEach($sitefinity in $sitefinities) {
            if ($sitefinity.name -eq $name) {
                $sitefinitiesParent = $data.SelectSingleNode('/data/sitefinities')
                $sitefinitiesParent.RemoveChild($sitefinity)
            }
        }

        $data.Save($dataPath) > $null
    } catch {
        throw "Error deleting sitefinity from ${dataPath}. Message: $_.Exception.Message"
    }
}

function _sfData-save-context {
    Param($context)

    _sfData-validate-context $context
    try {
        $data = New-Object XML
        $data.Load($dataPath)
        $sitefinities = $data.data.sitefinities.sitefinity
        ForEach($sitefinity in $sitefinities) {
            if ($sitefinity.name -eq $context.name) {
                $sitefinityEntry = $sitefinity
                break
            }
        }

        if ($sitefinityEntry -eq $null) {
            $sitefinityEntry = $data.CreateElement("sitefinity");
            $sitefinities = $data.SelectSingleNode('/data/sitefinities')
            $sitefinities.AppendChild($sitefinityEntry)
        }

        $sitefinityEntry.SetAttribute("name", $context.name)
        $sitefinityEntry.SetAttribute("displayName", $context.displayName)
        $sitefinityEntry.SetAttribute("solutionPath", $context.solutionPath)
        $sitefinityEntry.SetAttribute("webAppPath", $context.webAppPath)
        $sitefinityEntry.SetAttribute("dbName", $context.dbName)
        $sitefinityEntry.SetAttribute("websiteName", $context.websiteName)
        # $sitefinityEntry.SetAttribute("port", $context.port)
        # $sitefinityEntry.SetAttribute("appPool", $context.appPool)

        $data.Save($dataPath) > $null
    } catch {
        throw "Error creating sitefinity in ${dataPath} database file"
    }
}

function _sfData-init-data {
    if (!(Test-Path $dataPath)) {
        Write-Host "Initializing script data..."
        New-Item -ItemType file -Path $dataPath

        # Create The Document
        $XmlWriter = New-Object System.XMl.XmlTextWriter($dataPath,$Null)

        # Set The Formatting
        $xmlWriter.Formatting = "Indented"
        $xmlWriter.Indentation = "4"

        # Write the XML Decleration
        $xmlWriter.WriteStartDocument()
            $xmlWriter.WriteStartElement("data")
                $xmlWriter.WriteStartElement("sitefinities")
                $xmlWriter.WriteEndElement()
            $xmlWriter.WriteEndElement()
        $xmlWriter.Finalize
        # Finish The Document
        $xmlWriter.Flush()
        $xmlWriter.Close()
    }
}

#endregion

_sfData-init-data

_sfData-set-currentContext $null

sf-select-sitefinity