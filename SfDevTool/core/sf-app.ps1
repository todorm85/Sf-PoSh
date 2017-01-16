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
    .PARAMETER silentFinish
    Does not display a toaster notification when done.
    .OUTPUTS
    None
#>
function sf-reset-app {
    [CmdletBinding()]
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

    if ($start) {
        try {
            _sf-create-startupConfig
        } catch {
            throw "Erros while creating startupConfig: $_.Exception.Message"
        }
    }
    
    Write-Host "Restarting app threads..."
    sf-reset-thread

    if ($start) {
        Start-Sleep -s 2
        try {
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
        }
    }

    if (-not $silentFinish) {
        # display message
        os-popup-notification -msg "Operation completed!"
    }
}

New-Alias -name ra -value sf-reset-app

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
                $XmlWriter.WriteAttributeString("username", "admin@test.test")
                $XmlWriter.WriteAttributeString("password", "admin@2")
                $XmlWriter.WriteAttributeString("enabled", "True")
                $XmlWriter.WriteAttributeString("initialized", "False")
                $XmlWriter.WriteAttributeString("email", "admin@test.test")
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
