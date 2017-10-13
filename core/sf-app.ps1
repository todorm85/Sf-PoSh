<#
    .SYNOPSIS 
    Resets the current sitefinity instance state to its default.
    .DESCRIPTION
    Deletes the database, app data files and creates a startup config with default settings. Name of the database is the same as the name of the sitefinity instance when it was first provisioned/imported. Admin user is name:admin,pass:admin@2.
    .PARAMETER start
    If switch is passed sitefinity is automatically initialized after the reset.
    .PARAMETER configRestrictionSafe
    If passed checks whether ReadOnlyConfigFile restirction level is set in web.config and resets it to default. When finished the original value is returned.
    .PARAMETER rebuild
    Rebuilds the solution.
    .PARAMETER build
    Builds the solution.
    .PARAMETER user
    The username that will be used to initialize sitefinity if -start switch is passed as well.
    .PARAMETER silentFinish
    Does not display a toaster notification when done.
    .OUTPUTS
    None
#>
function sf-reset-app {
    [CmdletBinding()]
    Param(
        [switch]$start,
        [switch]$rebuild,
        [switch]$precompile,
        [switch]$build,
        [string]$user = $defaultUser,
        [switch]$configRestrictionSafe
        )

    $dbName = sf-get-dbName # this needs to be here before DataConfig.config gets deleted!!!
    
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

    if (-not [string]::IsNullOrEmpty($dbName)) {
        Write-Host "Deleting database..."
        try {
            sql-delete-database -dbName $dbName
        } catch {
            Write-Warning "Erros while deleting database: $_.Exception.Message"
        }
    }

    Write-Host "Restarting app threads..."
    sf-reset-thread

    if ($start) {
        Start-Sleep -s 2

        try {
            _sf-create-startupConfig $user $dbName
        } catch {
            throw "Erros while creating startupConfig: $_.Exception.Message"
        }

        try {
            $appUrl = _sf-get-appUrl
            _sf-start-sitefinity -url $appUrl
        } catch {
            Write-Host "`n`n"
            Write-Warning "ERROS WHILE INITIALIZING WEB APP. MOST LIKELY CAUSE: YOU MUST LOG OFF FROM THE WEBAPP INSTANCE IN THE BROWSER WHEN REINITIALIZING SITEFINITY INSTANCE OTHERWISE 'DUPLICATE KEY ERRORS' AND OTHER VARIOUS OPENACCESS EXCEPTIONS OCCUR WHEN USING STARTUPCONFIG`n"

            _sf-delete-startupConfig
            
            $choice = Read-Host "Display stack trace? [y/n]"
            while($true) {
                if ($choice -eq 'y') {
                    Write-Host "`n`nException: $($_.Exception)"
                    break
                }

                if ($choice -eq 'n') {
                    break
                }

                $choice = Read-Host "Display stack trace? [y/n]"
            }
        }
    }

    if ($precompile) {
        sf-add-precompiledTemplates
    }
    
    os-popup-notification -msg "Operation completed!"
}

function sf-save-appState {
    $context = _sf-get-context
    
    $dbName = sf-get-dbName
    if (-not $dbName) {
        throw "Current app is not initialized with a database. No databse name found in dataConfig.config"
    }
    
    while ($true) {
        $stateName = Read-Host -Prompt "Enter state name:"
        $statePath = "$($context.webAppPath)/states/$stateName"
        $configStatePath = "$statePath/configs"
        if(-not (Test-Path $configStatePath)) {
            New-Item $configStatePath -ItemType Directory > $null
            break;
        }
    }

    Backup-SqlDatabase -ServerInstance $sqlServerInstance -Database $dbName -BackupFile "$statePath/$dbName.bak"
    
    $stateDataPath = "$statePath/data.xml"
    New-Item $stateDataPath > $null
    $stateData = New-Object XML
    $root = $stateData.CreateElement("root")
    $stateData.AppendChild($root) > $null
    $root.SetAttribute("dbName", $dbName)
    $stateData.Save($stateDataPath) > $null

    $configsPath = "$($context.webAppPath)/App_Data/Sitefinity/Configuration"
    Copy-Item "$configsPath/*.*" $configStatePath
    
}

function _sf-get-statesPath {
    $context = _sf-get-context
    return "$($context.webAppPath)/states"
}

function sf-restore-appState {
    $context = _sf-get-context
    
    $stateName = _sf-select-appState
    $statesPath = _sf-get-statesPath
    $statePath = "${statesPath}/$stateName"
    $dbName = ([xml](Get-Content "$statePath/data.xml")).root.dbName
    sql-delete-database $dbName
    Restore-SqlDatabase -ServerInstance $sqlServerInstance -Database $dbName -BackupFile "$statePath/$dbName.bak"

    $configStatePath = "$statePath/configs"
    $configsPath = "$($context.webAppPath)/App_Data/Sitefinity/Configuration"
    if (Test-Path $configsPath) {
        Remove-Item "$configsPath/*" -Force -ErrorAction SilentlyContinue -Recurse
    } else {
        New-Item $configsPath -ItemType Directory > $null
    }
    
    Copy-Item "$configStatePath/*.*" $configsPath

    sf-reset-pool
}

function sf-delete-appState ($stateName) {
    $context = _sf-get-context
    
    if ([string]::IsNullOrEmpty($stateName)) {
        $stateName = _sf-select-appState
    }

    $statesPath = _sf-get-statesPath
    $statePath = "${statesPath}/$stateName"
    Remove-Item $statePath -Force -ErrorAction SilentlyContinue -Recurse    
}

function sf-delete-allAppStates {
    $statesPath = _sf-get-statesPath
    $states = Get-Item "${statesPath}/*"
    foreach ($state in $states) {
        sf-delete-appState $state.Name
    }
}

function _sf-select-appState {
    $context = _sf-get-context

    $statesPath = _sf-get-statesPath
    $states = Get-Item "${statesPath}/*"
    
    $i = 0
    foreach ($state in $states) {
        Write-Host :"$i : $($state.Name)"
        $i++
    }

    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose state'
        $stateName = $states[$choice].Name
        if ($stateName -ne $null) {
            break;
        }
    }

    return $stateName
}

<#
    .SYNOPSIS 
    Generates and adds precompiled templates to selected sitefinity solution.
    .DESCRIPTION
    Precompiled templates give much faster page loads when web app is restarted (when building or rebuilding solution) on first load of the page. Useful with local sitefinity development. WARNING: Any changes to markup are ignored when precompiled templates are added to the project, meaning the markup at the time of precompilation is always used. In order to see new changes to markup you need to remove the precompiled templates and generate them again.
    .PARAMETER revert
    Reverts previous changes
    .OUTPUTS
    None
#>
function sf-add-precompiledTemplates {
    [CmdletBinding()]
    param(
        [switch]$revert
    )
    
    # path to sitefinity compiler tool
    $sitefinityCompiler = "${PSScriptRoot}\..\external-tools\Telerik.Sitefinity.Compiler.exe"

    if (-not (Test-Path $sitefinityCompiler)) {
        Throw "Sitefinity compiler tool not found. You need to set the path to it inside the function"
    }
    
    $context = _sf-get-context
    $webAppPath = $context.webAppPath
    $appUrl = _sf-get-appUrl
    if ($revert) {
        $dlls = Get-ChildItem -Force "${webAppPath}\bin" | Where-Object { ($_.PSIsContainer -eq $false) -and (( $_.Name -like "Telerik.Sitefinity.PrecompiledTemplates.dll") -or ($_.Name -like "Telerik.Sitefinity.PrecompiledPages.Backend.0.dll")) }
        try {
            os-del-filesAndDirsRecursive $dlls
        } catch {
            throw "Item could not be deleted: $dll.PSPath`nMessage:$_.Exception.Message"
        }
    } else {
        & $sitefinityCompiler /appdir="${webAppPath}" /username="" /password="" /strategy="Backend" /membershipprovider="Default" /templateStrategy="Default" /url="${appUrl}"
    }
}

function sf-get-dbName {
    $context = _sf-get-context

    $data = New-Object XML
    $dataConfigPath = "$($context.webAppPath)\App_Data\Sitefinity\Configuration\DataConfig.config"
    if (Test-Path -Path $dataConfigPath) {
        $data.Load($dataConfigPath) > $null
        $conStr = $data.dataConfig.connectionStrings.add.connectionString
        $conStr -match 'initial catalog=(?<dbName>.*?)(;|$)' > $null
        $dbName = $matches['dbName']
        return $dbName
    } else {
        return $null
    }
}

function sf-rename-db {
    Param($newName)
    
    $context = _sf-get-context
    $dbName = sf-get-dbName
    if ([string]::IsNullOrEmpty($dbName)) {
        throw "Sitefinity not initiliazed with a database. No database found in DataConfig.config"
    }

    while (([string]::IsNullOrEmpty($newName)) -or (sql-test-isDbNameDuplicate $newName)) {
        $newName = $(Read-Host -Prompt "Db name duplicate in sql server! Enter new db name: ").ToString()
    }

    try {
        sql-rename-database $dbName $newName
    }
    catch {
        Write-Error "Failed renaming database in sql server.Message: $($_.Exception)"        
        return
    }

    try {
        sf-set-dbName $newName
    }
    catch {
        Write-Error "Failed renaming database in dataConfig"
        sql-rename-database $newName $dbName
        return
    }

    _sfData-save-context $context
}

function sf-set-dbName ($newName) {
    $context = _sf-get-context
    $dbName = sf-get-dbName
    if (-not $dbName) {
        Write-Host "No database configured for sitefinity."
    }

    $data = New-Object XML
    $dataConfigPath = "$($context.webAppPath)\App_Data\Sitefinity\Configuration\DataConfig.config"
    $data.Load($dataConfigPath) > $null
    $conStrElement = $data.dataConfig.connectionStrings.add
    $newString = $conStrElement.connectionString -replace $dbName, $newName
    $conStrElement.SetAttribute("connectionString", $newString)
    $data.Save($dataConfigPath) > $null
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

function _sf-delete-startupConfig {
    $context = _sf-get-context
    $configPath = "$($context.webAppPath)\App_Data\Sitefinity\Configuration\StartupConfig.config"
    Remove-Item -Path $configPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
    if ($ProcessError) {
        throw $ProcessError
    }
}

function _sf-create-startupConfig {
    param(
        [string]$user = $defaultUser,
        [string]$dbName = $null,
        [string]$password = $defaultPassword
    )

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
        
        $username = $user.split('@')[0]
        if ([string]::IsNullOrEmpty($dbName)) {
            $dbName = $context.name
        }

        while (sql-test-isDbNameDuplicate($dbName) -or [string]::IsNullOrEmpty($dbName)) {
            $dbName = Read-Host -Prompt "Database with name $dbName already exists. Enter a different name:"
        }

        $XmlWriter = New-Object System.XMl.XmlTextWriter($configPath,$Null)
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
                $XmlWriter.WriteAttributeString("sqlInstance", $sqlServerInstance)
            $xmlWriter.WriteEndElement()
        $xmlWriter.Finalize
        $xmlWriter.Flush()
        $xmlWriter.Close() > $null
    } catch {
        throw "Error creating startupConfig. Message: $_.Exception.Message"
    }
}
