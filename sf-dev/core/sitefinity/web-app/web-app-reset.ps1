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
    .OUTPUTS
    None
#>
function sf-app-reset {
    
    Param(
        [switch]$start,
        [switch]$rebuild,
        [switch]$precompile,
        [switch]$createStartupConfig,
        [switch]$build,
        [string]$user = $Global:Sf.config.sitefinityUser,
        [switch]$force,
        [SfProject]$project
    )

    $oldProject = $null
    if ($project) {
        [SfProject]$oldProject = sf-proj-getCurrent
        if ($oldProject -and ($oldProject.id -ne $project.id)) {
            sf-proj-setCurrent -newContext $project
        }
        else {
            $oldProject = $null
        }
    }
    else {
        $project = sf-proj-getCurrent
    }

    try {
        $dbName = sf-app-db-getName # this needs to be here before DataConfig.config gets deleted!!!
        if (!$dbName) {
            $dbName = $project.id
        }
    
        Write-Information "Restarting app pool..."
        sf-iis-pool-reset

        if ($force) {
            Write-Information "Unlocking files..."
            sf-sol-unlockAllFiles
        }
    
        if ($rebuild) {
            sf-sol-rebuild -retryCount 3
        }

        if ($build) {
            sf-sol-build -retryCount 3
        }

        Write-Information "Resetting App_Data files..."
        try {
            _sf-app-resetAppDataFiles
        }
        catch {
            Write-Information "Errors ocurred while resetting App_Data files.`n $_"
        }

        if ($dbName) {
            Write-Information "Deleting database..."
            try {
                $GLOBAL:Sf.sql.Delete($dbName)
            }
            catch {
                throw "Erros while deleting database: $_"
            }
        }

        if ($createStartupConfig) {
            _createStartupConfig $user $dbName
        }

        if ($start) {
            Start-Sleep -s 2

            try {
                _createStartupConfig $user $dbName
            }
            catch {
                throw "Erros while creating startupConfig: $_"
            }

            try {
                $appUrl = _getAppUrl
                sf-app-start -url $appUrl
            }
            catch {
                throw "ERROS WHILE INITIALIZING WEB APP. MOST LIKELY CAUSE:`n$_`n"
                _deleteStartupConfig
            }
        }

        if ($precompile) {
            sf-app-addPrecompiledTemplates
        }
    }
    finally {
        if ($oldProject) {
            sf-proj-setCurrent -newContext $oldProject
        }
    }
}

function sf-app-start {
    param(
        [Int32]$totalWaitSeconds = $Global:Sf.config.app.startupMaxWait
    )

    $url = _getAppUrl
    $statusUrl = "$url/appstatus"

    Write-Information "Starting Sitefinity..."
    $ErrorActionPreference = "Continue"

    # Send initial request to begin bootstrapping sitefinity
    $response = _invokeNonTerminatingRequest $url
    if ($response -and $response -ne 200 -and $response -ne 503) {
        throw "Could not make initial connection to Sitefinity. - StatusCode: $response"
    }

    # if sitefinity bootstrapped successfully appstatus should return 200 ok and it is in initializing state
    Write-Information "Checking Sitefinity status: '$statusUrl'"
    Write-Information "Sitefinity is initializing"
    $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        $response = _invokeNonTerminatingRequest $statusUrl
        if ($elapsed.Elapsed.TotalSeconds -gt $totalWaitSeconds) {
            throw "Sitefinity did NOT start in the specified maximum time"
        }

        if ($response -eq 200) {
            Write-Progress -Activity "Waiting for sitefinity to start" -PercentComplete (($elapsed.Elapsed.TotalSeconds / $totalWaitSeconds) * 100)
            Start-Sleep -s 5
            continue
        }

        # if request to appstatus returned 404, sitefinity has initialized
        if ($response -eq 404 -or $response -eq "NotFound") {
            $response = _invokeNonTerminatingRequest $url
            # if request to base url is 200 ok sitefinity has started
            if ($response -eq 200) {
                Write-Information "Sitefinity has started after $($elapsed.Elapsed.TotalSeconds) second(s)"
                break
            }
            else {
                throw "Sitefinity initialization failed!"
            }
        }
        else {
            throw "Sitefinity failed to start - StatusCode: $($response)"
        }   
    }
}

function _invokeNonTerminatingRequest ($url) {
    $result = $null
    try {
        $response = Invoke-WebRequest $url -TimeoutSec 120
        $result = $response.StatusCode
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode
        if ($statusCode) {
            $result = $statusCode.ToString()
        }
    }

    return $result
}

function _deleteStartupConfig {
    $context = sf-proj-getCurrent
    $configPath = "$($context.webAppPath)\App_Data\Sitefinity\Configuration\StartupConfig.config"
    Remove-Item -Path $configPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
    if ($ProcessError) {
        throw $ProcessError
    }
}

function _createStartupConfig {
    param(
        [string]$user = $GLOBAL:Sf.Config.sitefinityUser,
        [Parameter(Mandatory = $true)][string]$dbName,
        [string]$password = $GLOBAL:Sf.Config.sitefinityPassword,
        [string]$sqlUser = $GLOBAL:Sf.Config.sqlUser,
        [string]$sqlPass = $GLOBAL:Sf.Config.sqlPass
    )

    $context = sf-proj-getCurrent
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
        
        if (($GLOBAL:Sf.sql.isDuplicate($dbName)) -or [string]::IsNullOrEmpty($dbName)) {
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

function _sf-app-resetAppDataFiles {
    [SfProject]$context = sf-proj-getCurrent
    $webAppPath = $context.webAppPath
    $errorMessage = ''
    Set-Location $context.webAppPath
    if (Test-Path "$webAppPath\App_Data\Sitefinity") {
        $dirs = Get-ChildItem "$webAppPath\App_Data\Sitefinity" | Where-Object { ($_.PSIsContainer -eq $true) -and (( $_.Name -like "Configuration") -or ($_.Name -like "Temp") -or ($_.Name -like "Logs")) }
        try {
            if ($dirs) {
                $dirs | Remove-Item -Force -Recurse -ErrorVariable +errorMessage -ErrorAction SilentlyContinue
            }
        }
        catch {
            $errorMessage = "${errorMessage}`n" + $_
        }
    }

    if ($errorMessage -ne '') {
        throw $errorMessage
    }
}

function _sf-app-copyAppDataFiles ($dest) {
    [SfProject]$project = sf-proj-getCurrent

    $src = "$($project.webAppPath)\App_Data\*"
    Copy-Item -Path $src -Destination $dest -Recurse -Force -Confirm:$false -Exclude $(_sf-app-getAppDataFilesFilter)
}

function _sf-app-restoreAppDataFiles ($src) {
    [SfProject]$context = sf-proj-getCurrent
    $webAppPath = $context.webAppPath

    _sf-app-removeAppDataFiles
    Copy-Item -Path $src -Destination "$webAppPath\App_Data" -Confirm:$false -Recurse -Force -Exclude $(_sf-app-getAppDataFilesFilter) -ErrorVariable $errors -ErrorAction SilentlyContinue  # exclude is here for backward comaptibility
    if ($errors) {
        Write-Information "Some files could not be cleaned in AppData, because they might be in use."
    }
}

function _sf-app-removeAppDataFiles {
    [SfProject]$context = sf-proj-getCurrent
    $webAppPath = $context.webAppPath

    $toDelete = Get-ChildItem "${webAppPath}\App_Data" -Recurse -Force -Exclude $(_sf-app-getAppDataFilesFilter) -File
    $toDelete | ForEach-Object { unlock-allFiles -path $_.FullName }
    $errors
    $toDelete | Remove-Item -Force -ErrorAction SilentlyContinue -ErrorVariable +errors
    if ($errors) {
        Write-Information "Some files in AppData folder could not be cleaned up, perhaps in use?"
    }
    
    # clean empty dirs
    do {
        $dirs = Get-ChildItem "${webAppPath}\App_Data" -directory -recurse | Where-Object { (Get-ChildItem $_.fullName).Length -eq 0 } | Select-Object -expandproperty FullName
        $dirs | ForEach-Object { Remove-Item $_ -Force }
    } while ($dirs.count -gt 0)
}

function _sf-app-getAppDataFilesFilter {
    "*.pfx"
    "*.lic"
}