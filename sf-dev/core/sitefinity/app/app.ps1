function sd-app-waitForSitefinityToStart {
    param(
        [Int32]$totalWaitSeconds = $GLOBAL:sf.config.app.startupMaxWait
    )

    $url = sd-iisSite-getUrl
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

function sd-app-uninitialize {
    Param(
        [switch]$force
    )

    $project = sd-project-getCurrent
    if (!$project) {
        Write-Error "No project selected"
    }

    Write-Information "Restarting app pool..."
    sd-iisAppPool-Reset

    if ($force) {
        Write-Information "Unlocking files..."
        sd-sol-unlockAllFiles
    }

    Write-Information "Resetting App_Data files..."
    try {
        sd-sol-resetSitefinityFolder
    }
    catch {
        Write-Information "Errors ocurred while resetting App_Data files.`n $_"
    }

    Write-Information "Deleting database..."
    try {
        sql-delete-database -dbName $dbName
    }
    catch {
        throw "Erros while deleting database: $_"
    }
}

function sd-app-reinitializeAndStart {
    Param(
        [switch]$force
    )

    $project = sd-project-getCurrent

    $dbName = sd-db-getNameFromDataConfig # this needs to be here before DataConfig.config gets deleted!!!
    if (!$dbName) {
        $dbName = $project.id
    }

    sd-app-uninitialize -force:$force
    _app-initialize -dbName $dbName
}

<#
    .SYNOPSIS
    Generates and adds precompiled templates to selected sitefinity solution.
    .DESCRIPTION
    Precompiled templates give much faster page loads when web app is restarted (when building or rebuilding solution) on first load of the page. Useful with local sitefinity development. WARNING: Any changes to markup are ignored when precompiled templates are added to the project, meaning the markup at the time of precompilation is always used. In order to see new changes to markup you need to remove the precompiled templates and generate them again.
#>
function sd-appPrecompiledTemplates-add {
    # path to sitefinity compiler tool
    $sitefinityCompiler = "$PSScriptRoot\external-tools\Telerik.Sitefinity.Compiler.exe"

    if (-not (Test-Path $sitefinityCompiler)) {
        Throw "Sitefinity compiler tool not found. You need to set the path to it inside the function"
    }

    $context = sd-project-getCurrent
    $webAppPath = $context.webAppPath
    $appUrl = sd-iisSite-getUrl
    & $sitefinityCompiler /appdir="${webAppPath}" /username="" /password="" /strategy="Backend" /membershipprovider="Default" /templateStrategy="Default" /url="${appUrl}"
}

<#
    .SYNOPSIS
    Removes previously added precompiled templates to selected sitefinity solution.
#>
function sd-appPrecompiledTemplates-remove {
    # path to sitefinity compiler tool
    $sitefinityCompiler = "$PSScriptRoot\external-tools\Telerik.Sitefinity.Compiler.exe"

    if (-not (Test-Path $sitefinityCompiler)) {
        Throw "Sitefinity compiler tool not found. You need to set the path to it inside the function"
    }

    $context = sd-project-getCurrent
    $webAppPath = $context.webAppPath
    $dlls = Get-ChildItem -Force -Recurse "${webAppPath}\bin" | Where-Object { ($_.PSIsContainer -eq $false) -and (( $_.Name -like "Telerik.Sitefinity.PrecompiledTemplates.dll") -or ($_.Name -like "Telerik.Sitefinity.PrecompiledPages.Backend.0.dll")) }
    try {
        $dlls | Remove-Item -Force
    }
    catch {
        throw "Item could not be deleted: $dll.PSPath`nMessage:$_"
    }
}

function _app-initialize {
    param(
        [Parameter(Mandatory = $true)]$dbName
    )

    Start-Sleep -s 2
    try {
        sd-appStartupConfig-create $GLOBAL:sf.config.sitefinityUser $dbName
    }
    catch {
        throw "Erros while creating startupConfig: $_"
    }

    try {
        sd-app-waitForSitefinityToStart
    }
    catch {
        sd-appStartupConfig-remove
        throw "ERROS WHILE INITIALIZING WEB APP. MOST LIKELY CAUSE:`n$_`n"
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