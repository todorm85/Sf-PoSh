<#
    .SYNOPSIS 
    Builds the current sitefinity instance solution.
    .OUTPUTS
    None
#>
function sf-build-solution {
    [CmdletBinding()]

    $context = _get-selectedProject
    $solutionPath = "$($context.solutionPath)\Telerik.Sitefinity.sln"
    if (!(Test-Path $solutionPath)) {
        sf-build-webAppProj
    }

    _sf-build-proj $solutionPath
}

<#
    .SYNOPSIS 
    Does a true rebuild of the current sitefinity instance solution by deleteing all bin and obj folders and then builds.
    .OUTPUTS
    None
#>
function sf-rebuild-solution {
    [CmdletBinding()]
    Param([bool]$cleanPackages = $false)
    
    Write-Host "Rebuilding solution..."
    try {
        sf-clean-solution -cleanPackages $cleanPackages
    }
    catch {
        Write-Warning "Errors while cleaning solution: $_.Exception.Message"
    }

    sf-build-solution
}

function sf-clean-solution {
    Param([bool]$cleanPackages = $false)

    Write-Host "Cleaning solution..."
    Write-Warning "Cleaning solution will kill all current msbuild processes."
    $leftovers = Get-Process "msbuild" -ErrorAction "SilentlyContinue"
    if ($leftovers) {
        $leftovers | Stop-Process -Force
    }
    
    $context = _get-selectedProject
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
    }
    catch {
        $errorMessage = "Errors while deleting bins and objs:`n" + $_.Exception.Message
    }

    if ($errorMessage -ne '') {
        $errorMessage = "Errors while deleting bins and objs:`n$errorMessage"
    }

    if ($cleanPackages) {
        
        Write-Host "Deleting packages..."
        $dirs = Get-ChildItem "${solutionPath}\packages" | Where-Object { ($_.PSIsContainer -eq $true) }
        try {
            os-del-filesAndDirsRecursive $dirs
        }
        catch {
            $errorMessage = "$errorMessage`nErrors while deleting packages:`n" + $_.Exception.Message
        }
    }

    if ($errorMessage -ne '') {
        throw $errorMessage
    }
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-clear-nugetCache {
    [CmdletBinding()]
    Param()
    
    $context = _get-selectedProject
    if (!(Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }

    & "$($context.solutionPath)\.nuget\nuget.exe" locals all -clear
}

<#
    .SYNOPSIS 
    Opens the selected sitefinity solution.
    .DESCRIPTION
    If a webapp without solution was imported nothing is opened.
    .OUTPUTS
    None
#>
function sf-open-solution {
    [CmdletBinding()]
    Param(
        [switch]$useDefault
    )
    
    $context = _get-selectedProject
    $solutionPath = $context.solutionPath
    if ($solutionPath -eq '') {
        throw "invalid or no solution path"
    }

    if ($useDefault) {
        $solutionName = "Telerik.Sitefinity.sln"
    }
    else {
        $solutionName = _get-solutionFriendlyName
    }

    & $vsPath "${solutionPath}\${solutionName}"
}

<#
    .SYNOPSIS 
    Builds the current sitefinity instance webapp project file.
    .OUTPUTS
    None
#>
function sf-build-webAppProj () {
    [CmdletBinding()]

    $context = _get-selectedProject
    $path = "$($context.webAppPath)\SitefinityWebApp.csproj"
    if (!(Test-Path $path)) {
        throw "invalid or no solution or web app project path"
    }

    _sf-build-proj $path
}

function sf-save-solution () {
    $telerikSolution = "$($context.solutionPath)\Telerik.Sitefinity.sln"
    $customSolution = "$($context.solutionPath)\$(_get-solutionFriendlyName $context)"
    Copy-Item -Path $customSolution -Destination $telerikSolution -Force
}

function _sf-build-proj {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)][string]$path
    )

    if (!(Test-Path $path)) {
        throw "invalid or no proj path"
    }

    Write-Host "Building ${path}"

    # $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
    # $command = '"' + $msBuildPath + '" "' + $path + '"' + ' /nologo /maxcpucount /Verbosity:quiet /consoleloggerparameters:ErrorsOnly,Summary,PerformanceSummary'
    # Invoke-Expression "& $command"
    & $msBuildPath $path /nologo /maxcpucount /Verbosity:normal
    # & $Script:vsCmdPath $path /build Debug

    # $elapsed.Stop()
    # Write-Warning "Build took $($elapsed.Elapsed.TotalSeconds) second(s)"
    # Out-File "${PSScriptRoot}\..\build-errors.log"
    if ($LastExitCode -ne 0) {
        throw "Build errors occurred."
    }
}
