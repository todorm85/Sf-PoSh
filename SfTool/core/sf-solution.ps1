<#
    .SYNOPSIS 
    Opens the selected sitefinity solution.
    .DESCRIPTION
    If a webapp without solution was imported nothing is opened.
    .OUTPUTS
    None
#>
function sf-open-solution {
    
    [CmdletBinding()]param()
    
    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    if ($solutionPath -eq '') {
        throw "invalid or no solution path"
    }

    & $vsPath "${solutionPath}\telerik.sitefinity.sln"
}

<#
    .SYNOPSIS 
    Builds the current sitefinity instance solution.
    .DESCRIPTION
    If an existing sitefinity web app without a solution was imported nothing is done.
    .PARAMETER useOldMsBuild
    If switch is passed msbuild 4.0 tools will be used. (The one used by VS2012), Otherwise the default msbuild tools version is used, which for vs2015 is 14.0
    .OUTPUTS
    None
#>
function sf-build-solution {
    
    [CmdletBinding()]
    Param([switch]$useOldMsBuild)

    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

    Write-Verbose "Building solution ${solutionPath}\Telerik.Sitefinity.sln"
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

<#
    .SYNOPSIS 
    Does a true rebuild of the current sitefinity instance solution by deleteing all bin and obj folders and then builds.
    .OUTPUTS
    None
#>
function sf-rebuild-solution {
    [CmdletBinding()]param()
    
    Write-Verbose "Rebuilding solution..."
    try {
        _sf-clean-solution
    } catch {
        Write-Warning "Errors while cleaning solution: $_.Exception.Message"
    }

    sf-build-solution
}

function _sf-clean-solution {
    Write-Verbose "Cleaning solution..."
    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

    $errorMessage = ''
    #delete all bin, obj and packages
    Write-Verbose "Deleting bins and objs..."
    $dirs = Get-ChildItem -force -recurse $solutionPath | Where-Object { ($_.PSIsContainer -eq $true) -and (( $_.Name -like "bin") -or ($_.Name -like "obj")) }
    try {
        os-del-filesAndDirsRecursive $dirs
    } catch {
        $errorMessage = "Errors while deleting bins and objs:`n" + $_.Exception.Message
    }

    if ($errorMessage -ne '') {
        $errorMessage = "Errors while deleting bins and objs:`n$errorMessage"
    }

    Write-Verbose "Deleting packages..."
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
    Write-Verbose "Deleting sitefinity configs, logs, temps..."
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
