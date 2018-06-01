<#
    .SYNOPSIS 
    Builds the current sitefinity instance solution.
    .PARAMETER useOldMsBuild
    If switch is passed msbuild 4.0 tools will be used. (The one used by VS2012), Otherwise the default msbuild tools version is used, which for vs2015 is 14.0
    .OUTPUTS
    None
#>
function sf-build-solution {
    [CmdletBinding()]
    Param(
        [switch]$useOldMsBuild,
        [switch]$ui,
        [bool]$useTelerikSitefinity = $false
    )

    $context = _get-selectedProject
    $solutionName = _get-solutionName -useTelerikSitefinity $useTelerikSitefinity
    $solutionPath = "$($context.solutionPath)\${solutionName}"
    $solutionPathUI = "$($context.solutionPath)\Telerik.Sitefinity.MS.TestUI.sln"
    if (!(Test-Path $solutionPath)) {
        sf-build-webAppProj
    }

    _sf-build-proj $solutionPath $useOldMsBuild
    if ($ui) {
        _sf-build-proj $solutionPathUI $useOldMsBuild
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
    
    Write-Host "Rebuilding solution..."
    try {
        sf-clean-solution
    }
    catch {
        Write-Warning "Errors while cleaning solution: $_.Exception.Message"
    }

    sf-build-solution
}

function sf-clean-solution {
    Param([switch]$keepPackages)

    Write-Host "Cleaning solution..."
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

    if (-not $keepPackages) {
        
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
        [switch]$openUISln,
        [switch]$useTelerikSitefinity
    )
    
    $context = _get-selectedProject
    $solutionPath = $context.solutionPath
    if ($solutionPath -eq '') {
        throw "invalid or no solution path"
    }

    $solutionName = _get-solutionName -useTelerikSitefinity $useTelerikSitefinity
    if ($openUISln) {
        & $vsPath "${solutionPath}\${solutionName}"
        & $vsPath "${solutionPath}\Telerik.Sitefinity.MS.TestUI.sln"
    }
    else {
        # & $vsPath "${solutionPath}\Telerik.Sitefinity.sln"
        & $vsPath "${solutionPath}\${solutionName}"
    }
}

<#
    .SYNOPSIS 
    Builds the current sitefinity instance webapp project file.
    .PARAMETER useOldMsBuild
    If switch is passed msbuild 4.0 tools will be used. (The one used by VS2012), Otherwise the default msbuild tools version is used, which for vs2015 is 14.0
    .OUTPUTS
    None
#>
function sf-build-webAppProj () {
    [CmdletBinding()]
    Param([switch]$useOldMsBuild)

    $context = _get-selectedProject
    $path = "$($context.webAppPath)\SitefinityWebApp.csproj"
    if (!(Test-Path $path)) {
        throw "invalid or no solution or web app project path"
    }

    _sf-build-proj $path $useOldMsBuild
}

function _sf-build-proj {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)][string]$path, 
        [bool]$useOldMsBuild
    )

    if (!(Test-Path $path)) {
        throw "invalid or no proj path"
    }

    Write-Host "Building ${path}"
    if ($useOldMsBuild) {
        $output = & $msBuildPath /verbosity:quiet /nologo /tv:"4.0" $path 2>&1
    }
    else {
        $output = & $msBuildPath /verbosity:quiet /nologo $path 2>&1
    }

    if ($LastExitCode -ne 0) {
        throw "$output"
    }
}