<#
    .SYNOPSIS 
    Builds the current sitefinity instance solution.
    .OUTPUTS
    None
#>
function sf-build-solution {
    [CmdletBinding()]
    Param(
        $retryCount = 0
    )
    
    $context = _get-selectedProject
    $solutionPath = "$($context.solutionPath)\Telerik.Sitefinity.sln"
    
    $tries = 0
    $isBuilt = $false
    while ($tries -le $retryCount -and (-not $isBuilt)) {
        try {
            if (!(Test-Path $solutionPath)) {
                sf-build-webAppProj
            }
            else {
                build-proj $solutionPath
            }
            
            $isBuilt = $true
        }
        catch {
            $tries++
            if ($tries -le $retryCount) {
                Write-Warning "Build failed. Retrying..." 
            }
            else {
                Write-Warning "Solution could not build after $retryCount retries."
                throw
            }
        }
    }
}

<#
    .SYNOPSIS 
    Does a true rebuild of the current sitefinity instance solution by deleteing all bin and obj folders and then builds.
    .OUTPUTS
    None
#>
function sf-rebuild-solution {
    [CmdletBinding()]
    Param([bool]$cleanPackages = $false, $retryCount = 0)
    
    Write-Information "Rebuilding solution..."
    try {
        sf-clean-solution -cleanPackages $cleanPackages
    }
    catch {
        Write-Warning "Errors while cleaning solution: $_"
    }

    sf-build-solution -retryCount $retryCount
}

function sf-clean-solution {
    Param([bool]$cleanPackages = $false)

    Write-Information "Cleaning solution..."

    $context = _get-selectedProject
    $solutionPath = $context.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

    sf-unlock-allFiles

    $errorMessage = ''
    #delete all bin, obj and packages
    Write-Information "Deleting bins and objs..."
    $dirs = Get-ChildItem -force -recurse $solutionPath | Where-Object { ($_.PSIsContainer -eq $true) -and (( $_.Name -like "bin") -or ($_.Name -like "obj")) }
    try {
        if ($dirs -and $dirs.Length -gt 0) {
            $dirs | Remove-Item -Force -Recurse
        }
    }
    catch {
        $errorMessage = "$_`n"
    }

    if ($errorMessage -ne '') {
        $errorMessage = "Errors while deleting bins and objs:`n$errorMessage"
    }

    if ($cleanPackages -and (Test-Path "${solutionPath}\packages")) {
        
        Write-Information "Deleting packages..."
        $dirs = Get-ChildItem "${solutionPath}\packages" | Where-Object { ($_.PSIsContainer -eq $true) }
        try {
            if ($dirs -and $dirs.Length > 0) {
                $dirs | Remove-Item -Force -Recurse
            }
        }
        catch {
            $errorMessage = "$errorMessage`nErrors while deleting packages:`n" + $_
        }
    }

    if ($errorMessage -ne '') {
        throw $errorMessage
    }
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
        $solutionName = generate-solutionFriendlyName
    }

    execute-native "& `"$vsPath`" `"${solutionPath}\${solutionName}`"" -successCodes @(1)
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

    build-proj $path
}

function sf-unlock-allFiles {
    [SfProject]$proj = _get-selectedProject
    if ($proj.solutionPath -ne "") {
        $path = $proj.solutionPath
    }
    else {
        $path = $proj.webAppPath
    }

    if ($path) {
        unlock-allFiles $path
    }
}
function build-proj {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)][string]$path
    )

    if (!(Test-Path $path)) {
        throw "invalid or no proj path"
    }

    Write-Information "Building ${path}"

    $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
    # $command = '"' + $msBuildPath + '" "' + $path + '"' + ' /nologo /maxcpucount /Verbosity:quiet /consoleloggerparameters:ErrorsOnly,Summary,PerformanceSummary'
    # Invoke-Expression "& $command"
    $output = & $msBuildPath $path /nologo /maxcpucount /Verbosity:quiet /p:RunCodeAnalysis=False /consoleloggerparameters:Summary
    $output | ForEach-Object { Write-Verbose $_ }
    $elapsed.Stop()
    Write-Information "Build took $($elapsed.Elapsed.TotalSeconds) second(s)"
    # Out-File "${PSScriptRoot}\..\build-errors.log"
    if ($LastExitCode -ne 0) {
        throw "Build errors occurred."
    }
}
