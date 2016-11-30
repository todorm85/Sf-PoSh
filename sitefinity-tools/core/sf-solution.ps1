function sf-explore-appData {
    $context = _sf-get-context
    $webAppPath = $context.webAppPath

    cd "${webAppPath}\App_Data\Sitefinity"
}

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

function sf-clear-nugetCache {
    $context = _sf-get-context
    if (!(Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }

    & "$($context.solutionPath)\.nuget\nuget.exe" locals all -clear
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
    Param([switch]$useOldMsBuild)

    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

    Write-Host "Building solution ${solutionPath}\Telerik.Sitefinity.sln"
    if ($useOldMsBuild) {
        $output = & $msBUildPath /verbosity:quiet /nologo /tv:"4.0" "${solutionPath}\Telerik.Sitefinity.sln" 2>&1
    } else {
        $output = & $msBUildPath /verbosity:quiet /nologo "${solutionPath}\Telerik.Sitefinity.sln" 2>&1
    }

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

    if (Test-Path "${webAppPath}\App_Data\Telerik\Configuration") {
        $files = Get-ChildItem "${webAppPath}\App_Data\Telerik\Configuration" | Where-Object { ($_.PSIsContainer -eq $false) -and ($_.Name -like "sso.config") }
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
