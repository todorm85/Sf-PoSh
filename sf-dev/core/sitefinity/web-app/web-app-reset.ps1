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
function app_reset {
    
    Param(
        [switch]$start,
        [switch]$rebuild,
        [switch]$precompile,
        [switch]$_createStartupConfig,
        [switch]$build,
        [string]$user,
        [switch]$configRestrictionSafe,
        [switch]$force,
        [SfProject]$project
    )

    if (!$user) {
        $user = $Global:Sf.config.defaultUser
    }

    $oldProject = $null
    if ($project) {
        [SfProject]$oldProject = proj_getCurrent
        if ($oldProject -and ($oldProject.id -ne $project.id)) {
            proj_setCurrent -newContext $project
        }
        else {
            $oldProject = $null
        }
    }

    try {
        $dbName = app_db_getName # this needs to be here before DataConfig.config gets deleted!!!
    
        Write-Information "Restarting app pool..."
        srv_pool_resetPool

        if ($force) {
            Write-Information "Unlocking files..."
            sol_unlockAllFiles
        }
    
        if ($rebuild) {
            sol_rebuild -retryCount 3
        }

        if ($build) {
            sol_build -retryCount 3
        }

        Write-Information "Resetting App_Data files..."
        try {
            _resetAppDataFiles
        }
        catch {
            Write-Warning "Errors ocurred while resetting App_Data files.`n $_"
        }

        if (-not [string]::IsNullOrEmpty($dbName)) {
            Write-Information "Deleting database..."
            try {
                
                $tokoAdmin.sql.Delete($dbName)
            }
            catch {
                throw "Erros while deleting database: $_"
            }
        }

        if ($_createStartupConfig) {
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
                _startApp -url $appUrl
            }
            catch {
                throw "ERROS WHILE INITIALIZING WEB APP. MOST LIKELY CAUSE:`n$_`n"
                _deleteStartupConfig
            }
        }

        if ($precompile) {
            app_addPrecompiledTemplates
        }
    }
    finally {
        if ($oldProject) {
            proj_setCurrent -newContext $oldProject
        }
    }
}

function _startApp {
    param(
        [Int32]$totalWaitSeconds = 5 * 60
    )

    # $port = @(iis-get-websitePort $context.websiteName)[0]
    # if ($port -eq '' -or $null -eq $port) {
    #     throw "No port defined for selected sitefinity."
    # }
    # else {
    #     $url = "http://localhost:$($port)"
    # }

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
        Write-Information "..."
        $response = _invokeNonTerminatingRequest $statusUrl
        if ($elapsed.Elapsed.TotalSeconds -gt $totalWaitSeconds) {
            throw "Sitefinity did NOT start in the specified maximum time"
        }

        if ($response -eq 200) {
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
    $context = proj_getCurrent
    $configPath = "$($context.webAppPath)\App_Data\Sitefinity\Configuration\StartupConfig.config"
    Remove-Item -Path $configPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
    if ($ProcessError) {
        throw $ProcessError
    }
}

function _createStartupConfig {
    param(
        [string]$user = $GLOBAL:Sf.Config.defaultUser,
        [string]$dbName = $null,
        [string]$password = $GLOBAL:Sf.Config.defaultPassword,
        [string]$sqlUser = $GLOBAL:Sf.Config.sqlUser,
        [string]$sqlPass = $GLOBAL:Sf.Config.sqlPass
    )

    $context = proj_getCurrent
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
        
        $username = $user.split('@')[0]
        if ([string]::IsNullOrEmpty($dbName)) {
            $dbName = app_db_getName
        }
        
        
        if (($tokoAdmin.sql.isDuplicate($dbName)) -or [string]::IsNullOrEmpty($dbName)) {
            throw "Error creating startup.config. Database with name $dbName already exists."
        }

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

function _resetAppDataFiles {
    [SfProject]$context = proj_getCurrent
    $webAppPath = $context.webAppPath
    $errorMessage = ''
    $originalAppDataFilesPath = "${webAppPath}\sf-dev-tool\original-app-data"
    Set-Location $context.webAppPath
    if (Test-Path $originalAppDataFilesPath) {
        Write-Information "Restoring Sitefinity web app App_Data files to original state."
        _restoreSfRuntimeFiles "$originalAppDataFilesPath/*"
    }
    elseif (Test-Path "${webAppPath}\App_Data\Sitefinity") {
        Write-Warning "Original App_Data copy not found. Restore will fallback to simply deleting the following directories in .\App_Data\Sitefinity: Configuration, Temp, Logs"
        $dirs = Get-ChildItem "${webAppPath}\App_Data\Sitefinity" | Where-Object { ($_.PSIsContainer -eq $true) -and (( $_.Name -like "Configuration") -or ($_.Name -like "Temp") -or ($_.Name -like "Logs")) }
        try {
            if ($dirs) {
                $dirs | Remove-Item -Force -Recurse
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

function _cleanSfRuntimeFiles {
    [SfProject]$context = proj_getCurrent
    $webAppPath = $context.webAppPath

    $toDelete = Get-ChildItem "${webAppPath}\App_Data" -Recurse -Force -Exclude @("*.pfx", "*.lic") -File
    $toDelete | ForEach-Object { unlock-allFiles -path $_.FullName }
    $toDelete | Remove-Item -Force

    # clean empty dirs
    do {
        $dirs = Get-ChildItem "${webAppPath}\App_Data" -directory -recurse | Where-Object { (Get-ChildItem $_.fullName).Length -eq 0 } | Select-Object -expandproperty FullName
        $dirs | ForEach-Object { Remove-Item $_ -Force }
    } while ($dirs.count -gt 0)
}

function _copySfRuntimeFiles ([SfProject]$project, $dest) {
    if (-not $project) {
        [SfProject]$project = proj_getCurrent
    }

    $src = "$($project.webAppPath)\App_Data\*"

    Copy-Item -Path $src -Destination $dest -Recurse -Force -Confirm:$false -Exclude @("*.pfx", "*.lic")
}

function _restoreSfRuntimeFiles ($src) {
    [SfProject]$context = proj_getCurrent
    $webAppPath = $context.webAppPath

    _cleanSfRuntimeFiles
    Copy-Item -Path $src -Destination "$webAppPath\App_Data" -Confirm:$false -Recurse -Force -Exclude @("*.pfx", "*.lic") # exclude is here for backward comaptibility
}
