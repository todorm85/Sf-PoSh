function sf-reset-app {
    Param(
        [switch]$start,
        [switch]$configRestrictionSafe,
        [switch]$rebuild,
        [switch]$build,
        [switch]$silentFinish
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
    
    Write-Host "Restarting app threads..."
    sf-reset-thread

    if ($start) {
        Start-Sleep -s 2
        try {
            if ($configRestrictionSafe) {
                # set readonly off
                $oldConfigStroageSettings = sf-get-storageMode
                if ($null -ne $oldConfigStroageSettings -and $oldConfigStroageSettings -ne '') {
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

    if (-not $silentFinish) {
        # display message
        os-popup-notification -msg "Operation completed!"
    }
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
