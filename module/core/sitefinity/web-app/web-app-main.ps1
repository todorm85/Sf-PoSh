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
        [switch]$createStartupConfig,
        [switch]$build,
        [string]$user = $defaultUser,
        [switch]$configRestrictionSafe,
        [switch]$force
    )

    $dbName = sf-get-appDbName # this needs to be here before DataConfig.config gets deleted!!!
    
    Write-Host "Restarting app pool..."
    sf-reset-pool

    if ($force) {
        Write-Host "Unlocking files..."
        sf-unlock-allFiles
    }
    
    if ($rebuild) {
        sf-rebuild-solution
    }

    if ($build) {
        sf-build-solution
    }

    Write-Host "Resetting App_Data files..."
    try {
        reset-appDataFiles
    }
    catch {
        Write-Warning "Errors ocurred while deleting App_Data files. Usually .log files cannot be deleted because they are left locked by iis processes. While this does not prevent sitefinity from restarting you should keep in mind that the log files may contain polluted entries from previous runs. `nError Message: `n $_"
    }

    if (-not [string]::IsNullOrEmpty($dbName)) {
        Write-Host "Deleting database..."
        try {
            sql-delete-database -dbName $dbName
        }
        catch {
            Write-Warning "Erros while deleting database: $_"
        }
    }

    if ($createStartupConfig) {
        create-startupConfig $user $dbName
    }

    if ($start) {
        Start-Sleep -s 2

        try {
            create-startupConfig $user $dbName
        }
        catch {
            throw "Erros while creating startupConfig: $_"
        }

        try {
            $appUrl = get-appUrl
            start-app -url $appUrl
        }
        catch {
            Write-Host "`n`n"
            Write-Warning "ERROS WHILE INITIALIZING WEB APP. MOST LIKELY CAUSE: YOU MUST LOG OFF FROM THE WEBAPP INSTANCE IN THE BROWSER WHEN REINITIALIZING SITEFINITY INSTANCE OTHERWISE 'DUPLICATE KEY ERRORS' AND OTHER VARIOUS OPENACCESS EXCEPTIONS OCCUR WHEN USING STARTUPCONFIG`n"

            delete-startupConfig
            
            $choice = Read-Host "Display stack trace? [y/n]"
            while ($true) {
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
    $sitefinityCompiler = "$PSScriptRoot\external-tools\Telerik.Sitefinity.Compiler.exe"

    if (-not (Test-Path $sitefinityCompiler)) {
        Throw "Sitefinity compiler tool not found. You need to set the path to it inside the function"
    }
    
    $context = _get-selectedProject
    $webAppPath = $context.webAppPath
    $appUrl = get-appUrl
    if ($revert) {
        $dlls = Get-ChildItem -Force "${webAppPath}\bin" | Where-Object { ($_.PSIsContainer -eq $false) -and (( $_.Name -like "Telerik.Sitefinity.PrecompiledTemplates.dll") -or ($_.Name -like "Telerik.Sitefinity.PrecompiledPages.Backend.0.dll")) }
        try {
            os-del-filesAndDirsRecursive $dlls
        }
        catch {
            throw "Item could not be deleted: $dll.PSPath`nMessage:$_"
        }
    }
    else {
        & $sitefinityCompiler /appdir="${webAppPath}" /username="" /password="" /strategy="Backend" /membershipprovider="Default" /templateStrategy="Default" /url="${appUrl}"
    }
}

function start-app {
    param(
        [string]$url,
        [Int32]$totalWaitSeconds = 5 * 60
    )

    $context = _get-selectedProject
    $port = @(iis-get-websitePort $context.websiteName)[0]
    if ($port -eq '' -or $null -eq $port) {
        throw "No port defined for selected sitefinity."
    }
    else {
        $url = "http://localhost:$($port)"
    }

    $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
    $statusUrl = "$url/appstatus"

    Write-Host "Starting Sitefinity..."
    $ErrorActionPreference = "Continue"

    # Send initial request to begin bootstrapping sitefinity
    $response = _invoke-NonTerminatingRequest $url
    if ($response -ne 200 -and $response -ne 503) {
        throw "Could not make initial connection to Sitefinity. - StatusCode: $response"
    }

    # if sitefinity bootstrapped successfully appstatus should return 200 ok and it is in initializing state
    Write-Host "Checking Sitefinity status: '$statusUrl'"
    Write-Host "Sitefinity is initializing"
    while ($true) {
        Write-Host "..." -NoNewline
        $response = _invoke-NonTerminatingRequest $statusUrl
        if ($elapsed.Elapsed.TotalSeconds -gt $totalWaitSeconds) {
            throw "Sitefinity did NOT start in the specified maximum time"
        }

        if ($response -eq 200) {
            Start-Sleep -s 5
            continue
        }

        # if request to appstatus returned 404, sitefinity has initialized
        if ($response -eq 404) {
            $response = _invoke-NonTerminatingRequest $url
            # if request to base url is 200 ok sitefinity has started
            if ($response -eq 200) {
                Write-Warning "Sitefinity has started after $($elapsed.Elapsed.TotalSeconds) second(s)"
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

function _invoke-NonTerminatingRequest ($url) {
    try {
        $response = Invoke-WebRequest $url -TimeoutSec 120
        return $response.StatusCode
    }
    catch {
        return $_.Exception.Response.StatusCode.Value__
    }
}

function delete-startupConfig {
    $context = _get-selectedProject
    $configPath = "$($context.webAppPath)\App_Data\Sitefinity\Configuration\StartupConfig.config"
    Remove-Item -Path $configPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
    if ($ProcessError) {
        throw $ProcessError
    }
}

function create-startupConfig {
    param(
        [string]$user = $defaultUser,
        [string]$dbName = $null,
        [string]$password = $defaultPassword
    )

    $context = _get-selectedProject
    $webAppPath = $context.webAppPath
    
    Write-Host "Creating StartupConfig..."
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
            $dbName = $context.id
        }

        while (sql-test-isDbNameDuplicate($dbName) -or [string]::IsNullOrEmpty($dbName)) {
            $dbName = Read-Host -Prompt "Database with name $dbName already exists. Enter a different name:"
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
        $XmlWriter.WriteAttributeString("sqlInstance", $sqlServerInstance)
        $xmlWriter.WriteEndElement()
        $xmlWriter.Finalize
        $xmlWriter.Flush()
        $xmlWriter.Close() > $null
    }
    catch {
        throw "Error creating startupConfig. Message: $_"
    }
}

function reset-appDataFiles {
    [SfProject]$context = _get-selectedProject
    $webAppPath = $context.webAppPath
    $errorMessage = ''
    $originalAppDataFilesPath = "${webAppPath}\sf-dev-tool\original-app-data"
    Set-Location $context.webAppPath
    if (Test-Path $originalAppDataFilesPath) {
        Write-Warning "Restoring Sitefinity web app App_Data files to original state."
        restore-sfRuntimeFiles "$originalAppDataFilesPath/*"
    }
    elseif (Test-Path "${webAppPath}\App_Data\Sitefinity") {
        Write-Warning "Original App_Data copy not found. Restore will fallback to simply deleting the following directories in .\App_Data\Sitefinity: Configuration, Temp, Logs"
        $dirs = Get-ChildItem "${webAppPath}\App_Data\Sitefinity" | Where-Object { ($_.PSIsContainer -eq $true) -and (( $_.Name -like "Configuration") -or ($_.Name -like "Temp") -or ($_.Name -like "Logs"))}
        try {
            os-del-filesAndDirsRecursive $dirs
        }
        catch {
            $errorMessage = "${errorMessage}`n" + $_
        }
    } 

    if ($errorMessage -ne '') {
        throw $errorMessage
    }
}

function clean-sfRuntimeFiles {
    [SfProject]$context = _get-selectedProject
    $webAppPath = $context.webAppPath

    Get-ChildItem "${webAppPath}\App_Data\*" -Recurse | Remove-Item -Force -Confirm:$false -Recurse -Exclude @("*.pfx", "*.lic")
    do {
        $dirs = Get-ChildItem "${webAppPath}\App_Data\*" -directory -recurse | Where-Object { (Get-ChildItem $_.fullName).Length -eq 0 } | Select-Object -expandproperty FullName
        $dirs | Foreach-Object { Remove-Item $_ }
    } while ($dirs.count -gt 0)
}

function copy-sfRuntimeFiles ($dest) {
    [SfProject]$context = _get-selectedProject
    $src = "$($context.webAppPath)\App_Data\*"

    Copy-Item -Path $src -Destination $dest -Recurse -Force -Confirm:$false -Exclude @("*.pfx", "*.lic")
}

function restore-sfRuntimeFiles ($src) {
    [SfProject]$context = _get-selectedProject
    $webAppPath = $context.webAppPath

    clean-sfRuntimeFiles
    Copy-Item -Path $src -Destination "$webAppPath\App_Data" -Confirm:$false -Recurse -Force -Exclude @("*.pfx", "*.lic") # exclude is here for backward comaptibility
}