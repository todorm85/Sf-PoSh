# Environment Constants
$sqlServerInstance = '.' # the name of the local sql server instance that is used to connect
$browserPath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
$vsPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe"
$msBUildPath = "C:\Program Files (x86)\MSBuild\14.0\Bin\msbuild.exe"
$tfPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\tf.exe" # used for tfs workspace manipulations, installed with Visual Studio
$sitefinityCompiler = "D:\Tools\SitefinityCompiler\SitefinityCompiler\bin\Release\Telerik.Sitefinity.Compiler.exe" # needed if you use precompiled templates functions can be found at $/CMS/Sitefinity 4.0/Tools/Telerik.WebTestRunner

# Sript constants
$scriptPath = $MyInvocation.ScriptName
$dataPath = "${PSScriptRoot}\sf-data.xml"

# Hardcoded settings
$defaultBranch = "$/CMS/Sitefinity 4.0/OfficialReleases/DBP"
$webAppUser = 'admin'
$webAppUserPass = 'admin@2'
$dbpAccountId = "da122e15-9199-45ae-9e06-d2847f81d1fe"

# Usings
. "${PSScriptRoot}\common\iis.ps1"
. "${PSScriptRoot}\common\sql.ps1" $sqlServerInstance
. "${PSScriptRoot}\common\os.ps1"
. "${PSScriptRoot}\common\tfs.ps1" $tfPath
Import-Module "WebAdministration"

#region PUBLIC

# Sitefinity instances management

function sf-create-sitefinity {
    Param(
        [Parameter(Mandatory=$true)][string]$name,
        [string]$branch = $defaultBranch
        )

    $defaultContext = _sfData-get-defaultContext -name $name
    try {
        $newContext = @{ name = $defaultContext.name }
        if (Test-Path $defaultContext.solutionPath) {
            throw "Path already exists:" + $defaultContext.solutionPath
        }

        Write-Host "Creating solution path..."
        New-Item $defaultContext.solutionPath -type directory > $null
        $newContext.solutionPath = $defaultContext.solutionPath;

        # create and map workspace
        Write-Host "Creating workspace..."
        tfs-create-workspace $defaultContext.workspaceName $defaultContext.solutionPath
        $newContext.workspaceName = $defaultContext.workspaceName;

        Write-Host "Creating workspace mappings..."
        tfs-create-mappings -branch $branch -branchMapPath $defaultContext.solutionPath -workspaceName $defaultContext.workspaceName

        Write-Host "Getting latest workspace changes..."
        tfs-get-latestChanges -branchMapPath $defaultContext.solutionPath
           
        # persist current context to script data
        $newContext.dbName = $defaultContext.dbName
        $oldContext = ''
        $oldContext = _sfData-get-currentContext
        _sfData-set-currentContext $newContext
        _sfData-save-context $newContext
    } catch {
        Write-Host "############ CLEANING UP ############"
        Set-Location $PSScriptRoot
        if ($newContext.solutionPath -ne '') {
            Remove-Item -Path $newContext.solutionPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            if ($ProcessError) {
                Write-Host $ProcessError
            }
        }

        if ($newContext.workspaceName -ne '') {
            tfs-delete-workspace $newCOntext.workspaceName
        }

        if ($oldContext -ne '') {
            _sfData-set-currentContext $oldContext
        }

        throw "Nothing created. Try again. Error: $_.Exception.Message"
    }
    
    $startWebApp = $true
    
    try {
        Write-Host "Building solution..."
        sf-build-solution
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

function sf-show-sitefinities {

    _sfData-get-allContexts
}

function sf-delete-sitefinity {
    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    $workspaceName = $context.workspaceName
    $dbName = $context.dbName
    $websiteName = $context.websiteName

    while ($true) {
        $isConfirmed = Read-Host -Prompt "WARNING! Current operation will reset IIS. You also need to have closed the current sitefinity solution in Visual Studio and any opened browsers for complete deletion. Continue [y/n]?"
        if ($isConfirmed -eq 'y') {
            break;
        }

        if ($isConfirmed -eq 'n') {
            return
        }
    }

    Set-Location -Path $PSScriptRoot

    # Del workspace
    Write-Host "Deleting workspace..."
    if ($workspaceName -ne '') {
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
    Write-Host "Resetting IIS and deleting solution directory..."
    try {
        iisreset.exe > $null
        Remove-Item $solutionPath -recurse -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
        if ($ProcessError) {
            throw $ProcessError
        }
    } catch {
        Write-Host "Errors deleting sitefinity directory ${solutionPath}. $_.Exception.Message"
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
        Write-Host  $index : $sitefinity.name
    }

    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose sitefinity'
        $selectedSitefinity = $sitefinities[$choice]
        if ($selectedSitefinity -ne $null) {
            break;
        }
    }

    _sfData-set-currentContext $selectedSitefinity
}

function sf-show-sitefinityDetails {
    $context = _sf-get-context
    if ($context.websiteName -eq '' -or $context.websiteName -eq $null) {
        $websiteName = ''
    } else {
        $websiteName = "http://localhost:$($context.port)"
    }

    $sitefinity = @(
        [pscustomobject]@{id = 1; Parameter = "Sitefinity name"; Value = $context.name;},
        [pscustomobject]@{id = 2; Parameter = "Solution Path"; Value = $context.solutionPath;},
        [pscustomobject]@{id = 2; Parameter = "Workspace name"; Value = $context.workspaceName;},
        [pscustomobject]@{id = 3; Parameter = "Database Name"; Value = $context.dbName;},
        [pscustomobject]@{id = 4; Parameter = "Website Name in IIS"; Value = $context.websiteName;},
        [pscustomobject]@{id = 5; Parameter = "Website address"; Value = $websiteName;},
        [pscustomobject]@{id = 6; Parameter = "Application Pool"; Value = $context.appPool;}
    )

    $sitefinity | Sort-Object -Property id | Format-Table -Property Parameter, Value -auto
}

# Web app management

function sf-open-webApp {
    $context = _sf-get-context
    $port = $context.port
    if ($port -eq '' -or $port -eq $null) {
        throw "No sitefinity port set."
    }

    & $browserPath "http://localhost:${port}/Sitefinity" -noframemerging
}

function sf-add-precompiledTemplates {
    $context = _sf-get-context
    $solutionPath = $context.solutionPath

    & $sitefinityCompiler /appdir="${solutionPath}\SitefinityWebApp" /username="" /password="" /strategy="Backend" /membershipprovider="Default" /templateStrategy="Default"
}

function sf-remove-precompiledTemplates {
    $context = _sf-get-context
    $solutionPath = $context.solutionPath

    $dlls = Get-ChildItem -Force "${solutionPath}\SitefinityWebApp\bin" | Where-Object { ($_.PSIsContainer -eq $false) -and (( $_.Name -like "Telerik.Sitefinity.PrecompiledTemplates.dll") -or ($_.Name -like "Telerik.Sitefinity.PrecompiledPages.Backend.0.dll")) }
    try {
        os-del-filesAndDirsRecursive $dlls
    } catch {
        throw "Item could not be deleted: $dll.PSPath`nMessage:$_.Exception.Message"
    }
}
 
function sf-reset-webApp {
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

    if ($start) {
        try {
            if ($configRestrictionSafe) {
                # set readonly off
                $oldConfigStroageSettings = sf-get-storageMode
                sf-set-storageMode -storageMode $oldConfigStroageSettings.StorageMode -restrictionLevel "Default"
            }

            _sf-create-startupConfig
            _sf-start-sitefinity -url "http://localhost:$($context.port)"
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
                sf-set-storageMode -storageMode $oldConfigStroageSettings.StorageMode -restrictionLevel $oldConfigStroageSettings.RestrictionLevel
            }
        }
    }

    # display message
    os-popup-notification -msg "Operation completed!"
}

#Solution

function sf-get-latest {
    $context = _sf-get-context
    $solutionPath = $context.solutionPath

    if ($solutionPath -eq '') {
        throw "Solution path is not set."
    }

    Write-Host "Getting latest changes for path ${solutionPath}."
    tfs-get-latestChanges -branchMapPath $solutionPath
    Write-Host "Getting latest changes complete."
}

function sf-open-solution {
    $context = _sf-get-context
    $solutionPath = $context.solutionPath

    & $vsPath "${solutionPath}\telerik.sitefinity.sln"
}

function sf-build-solution {
    $context = _sf-get-context
    $solutionPath = $context.solutionPath

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
    $solutionPath = $context.solutionPath

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

    $webConfigPath = $solutionPath + '\SitefinityWebApp\web.config'
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
        $telerikHandler.SetAttribute('requirePermissions', 'false')

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
    $solutionPath = $context.solutionPath

    # set web.config readonly off
    $webConfigPath = $solutionPath + '\SitefinityWebApp\web.config'
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

function sf-load-configFromDbToFile {
    Param(
        [Parameter(Mandatory=$true)]$configName,
        $filePath="${Env:userprofile}\Desktop\dbConfig.xml"
        )
    
    $context = _sf-get-context
    $config = sql-get-items -dbName $context.dbName -tableName 'sf_xml_config_items' -selectFilter 'dta' -whereFilter "path='${configName}'"

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

function sf-clear-configFromDb {
    Param(
        [Parameter(Mandatory=$true)]$configName
        )
    
    $context = _sf-get-context
    sql-delete-items -dbName $context.dbName -tableName 'sf_xml_config_items' -whereFilter "path='${configName}'"
}

# DBP

function sf-install-dbp {
    Param (
        [string]$accountId = $dbpAccountId
        )

    $context = _sf-get-context
    $solutionPath = $context.solutionPath

    & "${solutionPath}\Builds\DBPModuleSetup\dbp.ps1" -organizationAccountId $accountId -port $port
}

function sf-uninstall-dbp {
    Param (
        [string]$accountId = $dbpAccountId
        )

    $context = _sf-get-context
    $solutionPath = $context.solutionPath

    & "${solutionPath}\Builds\DBPModuleSetup\dbp.ps1" -organizationAccountId $accountId -port $port -rollback $true
}

# IIS

function sf-reset-appPool {
    Param([switch]$start)

    $context = _sf-get-context
    $appPool = $context.appPool
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

    $context.appPool = $selectedPool.name
    _sfData-save-context $context
}

# Misc

function sf-clear-nugetCache {

    & "${solutionPath}\.nuget\nuget.exe" locals all -clear
}

function sf-open-appData {
    $context = _sf-get-context
    $solutionPath = $context.solutionPath

    cd "${solutionPath}\SitefinityWebApp\App_Data\Sitefinity"
}

#endregion

#region PRIVATE

function _sf-delete-startupConfig {
    $context = _sf-get-context
    $configPath = "$($context.solutionPath)\SitefinityWebApp\App_Data\Sitefinity\Configuration\StartupConfig.config"
    Remove-Item -Path $configPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
    if ($ProcessError) {
        throw $ProcessError
    }
}

function _sf-create-startupConfig {
    $context = _sf-get-context
    $solutionPath = $context.solutionPath

    Write-Host "Creating StartupConfig..."
    try { 
        $appConfigPath = "${solutionPath}\SitefinityWebApp\App_Data\Sitefinity\Configuration"
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
    if ($context.port -eq '' -or $context.port -eq $null) {
        throw "No port defined for selected sitefinity."
    } else {
        $url = "http://localhost:$($context.port)"
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
    $solutionPath = $context.solutionPath
    $errorMessage = ''
    if (Test-Path "${solutionPath}\SitefinityWebApp\App_Data\Sitefinity") {
        $dirs = Get-ChildItem "${solutionPath}\SitefinityWebApp\App_Data\Sitefinity" | Where-Object { ($_.PSIsContainer -eq $true) -and (( $_.Name -like "Configuration") -or ($_.Name -like "Temp") -or ($_.Name -like "Logs"))}
        try {
            os-del-filesAndDirsRecursive $dirs
        } catch {
            $errorMessage = "${errorMessage}`n" + $_.Exception.Message
        }
    }

    if (Test-Path "${solutionPath}\SitefinityWebApp\App_Data\Telerik") {
        $files = Get-ChildItem "${solutionPath}\SitefinityWebApp\App_Data\Telerik" | Where-Object { ($_.PSIsContainer -eq $false) -and ($_.Name -like "sso.config") }
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
    $solutionPath = $context.solutionPath
    $websiteName = $context.websiteName

    if ($context.websiteName -ne '' -and $context.websiteName -ne $null) {
        throw 'Current context already has a website assigned!'
    }

    $newAppPath = "${solutionPath}\SitefinityWebApp"
    try {
        $site = iis-create-website -newWebsiteName $newWebsiteName -newPort $newPort -newAppPath $newAppPath -newAppPool $newAppPool
        $context.websiteName = $site.name
        $context.port = $site.port
        $context.appPool = $site.appPool
        _sfData-save-context $context
    } catch {
        $context.websiteName = ''
        $context.port = ''
        $context.appPool = ''
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
    $oldPort = $context.port
    $oldAppPool = $context.appPool
    $context.websiteName = ''
    $context.port = ''
    $context.appPool = ''
    try {
        _sfData-save-context $context
        Remove-WebSite -Name $websiteName
    } catch {
        $context.websiteName = $oldWebsiteName
        $context.port = $oldPort
        $context.appPool = $oldAppPool
        _sfData-save-context $context
        throw "Error: $_.Exception.Message"
    }
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

        if (-not (Test-Path $context.solutionPath)) {
            throw "Invalid sitefinity context. No solution path or it does not exist."
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
    $solutionPath = "d:\${name}";
    $websiteName = $name
    $workspaceName = $name
    $appPool = "DefaultAppPool"

    # initial port to start checking from
    $port = 1111
    while(!(os-test-isPortFree $port) -or !(iis-test-isPortFree $port)) {
        $port++
    }

    $dbName = $name
    while ((sql-test-isDbNameDuplicate $dbName)) {
        $dbName = Read-Host -Prompt "Database $($dbName) exists. Enter database name: "
    }

    $defaultContext.solutionPath = $solutionPath
    $defaultContext.dbName = $dbName
    $defaultContext.websiteName = $websiteName
    $defaultContext.workspaceName = $workspaceName
    $defaultContext.appPool = $appPool
    $defaultContext.port = $port
}

function _sfData-get-defaultContext {
    Param(
        [Parameter(Mandatory=$true)][string]$name
        )

    # build default context object
    $defaultContext = @{
        name = $name;
        solutionPath = '';
        dbName = '';
        websiteName = '';
        workspaceName = '';
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

    $sitefinities = @(_sfData-get-allContexts)
    foreach ($sitefinity in $sitefinities) {
        if ($sitefinity.name -eq $name) {
            Write-Host "Sitefinity name already used. ${name}"
            $name = Read-Host -Prompt 'Enter new sitefinity name: '
            _sfData-get-defaultContext
            return
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
        $sitefinityEntry.SetAttribute("solutionPath", $context.solutionPath)
        $sitefinityEntry.SetAttribute("workspaceName", $context.workspaceName)
        $sitefinityEntry.SetAttribute("dbName", $context.dbName)
        $sitefinityEntry.SetAttribute("websiteName", $context.websiteName)
        $sitefinityEntry.SetAttribute("port", $context.port)
        $sitefinityEntry.SetAttribute("appPool", $context.appPool)

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