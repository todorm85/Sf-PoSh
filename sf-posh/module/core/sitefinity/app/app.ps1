function sf-app-ensureRunning {
    param(
        [Int32]$totalWaitSeconds = $GLOBAL:sf.config.app.startupMaxWait
    )

    [SfProject]$p = sf-PSproject-get
    if (!$p.websiteName) {
        throw "No website found for project."
    }

    if (!(Get-Website $p.websiteName)) {
        throw "Website $($p.websiteName) for project does not exist."
    }

    if (!(iis-site-isStarted $p.websiteName)) {
        Start-Website -Name $p.websiteName
        if (!(iis-site-isStarted $p.websiteName)) {
            throw "Website $($p.websiteName) is stopped in IIS. Duplicate port?"
        }    
    }

    $dbName = sf-db-getNameFromDataConfig
    if ($dbName) {
        if (!(sql-get-dbs | ? name -eq $dbName)) {
            throw "Project database $dbName not found in database server."
        }
    }
    else {
        $startupConfigPath = "$($p.webAppPath)\App_Data\Sitefinity\Configuration\StartupConfig.config"
        if (!(Test-Path $startupConfigPath)) {
            throw "No data config found and no startup config found."
        }
    }

    $url = sf-iis-site-getUrl
    if (!$url) {
        throw "Error consturcting the site url. Details: $_"
    }

    Write-Information "Starting Sitefinity..."
    $ErrorActionPreference = "Continue"

    # Send initial request to begin bootstrapping sitefinity
    $response = _invokeNonTerminatingRequest $url
    if ($response -and $response -ne 200 -and $response -ne 503) {
        throw "Could not make initial connection to Sitefinity. - StatusCode: $response"
    }

    # if sitefinity bootstrapped successfully appstatus should return 200 ok and it is in initializing state
    $statusUrl = "$url/appstatus"
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

function sf-app-initialize {
    param(
        [switch]$skipSendRequestAndEnsureInitialized
    )

    [SfProject]$p = sf-PSproject-get
    if (!$p) {
        throw "No project selected."
    }

    if (sf-db-getNameFromDataConfig) {
        throw "Already initialized. Uninitialize first."
    }

    Start-Sleep -s 1
    try {
        $dbName = $p.id
        sql-delete-database $dbName
        sf-config-Startup-create -dbName $dbName
    }
    catch {
        throw "Erros while creating startupConfig: $_"
    }
    
    try {
        if (-not $skipSendRequestAndEnsureInitialized) {
            sf-app-ensureRunning
        }
    }
    catch {
        throw "ERROS WHILE INITIALIZING WEB APP. MOST LIKELY CAUSE:`n$_`n"
    }
}

function sf-app-uninitialize {
    Param(
        [switch]$force
    )

    $project = sf-PSproject-get
    if (!$project) {
        Write-Error "No project selected"
    }
    
    # not deleting the db as it might be used by other project if shared, if not it will be removed when sf-PSproject-remove is called
    
    try {
        sf-iis-appPool-Reset
        if ($force) {
            sf-sol-unlockAllFiles
        }

        $dbName = sf-db-getNameFromDataConfig
        if ($dbName) {
            sql-delete-database $dbName
        }
        
        sf-sol-resetSitefinityFolder
    }
    catch {
        Write-Warning "Errors ocurred while removing App_Data files.`n $_"
    }
}

function sf-app-reinitialize {
    Param(
        [switch]$force
    )

    sf-app-uninitialize -force:$force
    sf-app-initialize
}

<#
    .SYNOPSIS
    Generates and adds precompiled templates to selected sitefinity solution.
    .DESCRIPTION
    Precompiled templates give much faster page loads when web app is restarted (when building or rebuilding solution) on first load of the page. Useful with local sitefinity development. WARNING: Any changes to markup are ignored when precompiled templates are added to the project, meaning the markup at the time of precompilation is always used. In order to see new changes to markup you need to remove the precompiled templates and generate them again.
#>
function sf-precompiledTemplates-add {
    # path to sitefinity compiler tool
    $sitefinityCompiler = _sd-appPrecompiledTemplates-getCompilerPath

    if (-not (Test-Path $sitefinityCompiler)) {
        Throw "Sitefinity compiler tool not found. You need to set the path to it inside the function"
    }

    $context = sf-PSproject-get
    $webAppPath = $context.webAppPath
    $appUrl = sf-iis-site-getUrl
    & $sitefinityCompiler /appdir="${webAppPath}" /username="" /password="" /strategy="Backend" /membershipprovider="Default" /templateStrategy="Default" /url="${appUrl}"
}

<#
    .SYNOPSIS
    Removes previously added precompiled templates to selected sitefinity solution.
#>
function sf-precompiledTemplates-remove {
    # path to sitefinity compiler tool
    $sitefinityCompiler = _sd-appPrecompiledTemplates-getCompilerPath

    if (-not (Test-Path $sitefinityCompiler)) {
        Throw "Sitefinity compiler tool not found. You need to set the path to it inside the function"
    }

    $context = sf-PSproject-get
    $webAppPath = $context.webAppPath
    $dlls = Get-ChildItem -Force -Recurse "${webAppPath}\bin" | Where-Object { ($_.PSIsContainer -eq $false) -and (( $_.Name -like "Telerik.Sitefinity.PrecompiledTemplates.dll") -or ($_.Name -like "Telerik.Sitefinity.PrecompiledPages.Backend.0.dll")) }
    try {
        $dlls | Remove-Item -Force
    }
    catch {
        throw "Item could not be deleted: $dll.PSPath`nMessage:$_"
    }
}

function sf-app-isInitialized {
    param (
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project
    )
    
    process {
        Run-InFunctionAcceptingProjectFromPipeline {
            param($project)
            try {
                sf-app-ensureRunning > $null
            }
            catch {
                return $false        
            }
        
            return $true
        }
    }
}

function _sd-appPrecompiledTemplates-getCompilerPath() {
    "$PSScriptRoot\external-tools\compiler\Telerik.Sitefinity.Compiler.exe"
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
