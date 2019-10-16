<#
    .SYNOPSIS 
    Builds the current sitefinity instance solution.
    .OUTPUTS
    None
#>
function sf-sol-build {
    Param(
        $retryCount = 0
    )
    
    $project = sf-proj-getCurrent

    $solutionPath = "$($project.solutionPath)\Telerik.Sitefinity.sln"
    
    $tries = 0
    $isBuilt = $false
    while ($tries -le $retryCount -and (-not $isBuilt)) {
        try {
            if (!(Test-Path $solutionPath)) {
                sf-sol-buildWebAppProj
            }
            else {
                try {
                    _switchStyleCop -enable:$false
                    _buildProj $solutionPath
                }
                finally {
                    _switchStyleCop -enable:$true
                }
            }
            
            $isBuilt = $true
        }
        catch {
            $tries++
            if ($tries -le $retryCount) {
                Write-Information "Build failed. Retrying..." 
            }
            else {
                throw "Solution could not build after $retryCount retries. $_"
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
function sf-sol-rebuild {
    
    Param(
        [bool]$cleanPackages = $false,
        $retryCount = 0)
    
    Write-Information "Rebuilding solution..."
    try {
        sf-sol-clean -cleanPackages $cleanPackages
    }
    catch {
        Write-Information "Errors while cleaning solution: $_"
    }

    sf-sol-build -retryCount $retryCount
}

function sf-sol-clean {
    Param(
        [bool]$cleanPackages = $false)

    Write-Information "Cleaning solution..."
    $project = sf-proj-getCurrent

    $solutionPath = $project.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

    sf-sol-unlockAllFiles

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

    if ($cleanPackages) {
        try {
            sf-sol-clearPackages
        }
        catch {
            $errorMessage = "$errorMessage`nErrors while deleting packages:`n" + $_
        }
    }

    if ($errorMessage -ne '') {
        throw $errorMessage
    }
}

function sf-sol-clearPackages {
    [SfProject]$project = sf-proj-getCurrent
    $solutionPath = $project.solutionPath
    if (!(Test-Path "${solutionPath}\packages")) {
        Write-Information "No packages to delete"
        return
    }

    Write-Information "Deleting packages..."
    $dirs = Get-ChildItem "${solutionPath}\packages" | Where-Object { ($_.PSIsContainer -eq $true) }
    if ($dirs -and $dirs.Length -gt 0) {
        $dirs | Remove-Item -Force -Recurse
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
function sf-sol-open {
    Param(
        [switch]$useDefault
    )

    $project = sf-proj-getCurrent
    
    if (!$project.solutionPath -and !$project.webAppPath) {
        throw "invalid or no solution path and webApp path"
    }

    $path = $project.solutionPath

    if (!$path) {
        $path = $project.webAppPath
        $projectName = "SitefinityWebApp.csproj"
    }
    else {
        if ($useDefault) {
            $projectName = "Telerik.Sitefinity.sln"
        }
        else {
            $projectName = _generateSolutionFriendlyName
        }
    }

    $vsPath = $Global:Sf.config.vsPath
    if (!(Test-Path $vsPath)) {
        throw "Invalid visual studio path configured ($vsPath). Configure it in $Script:userConfigPath -> vsPath"
    }

    execute-native "& `"$vsPath`" `"$path\$projectName`"" -successCodes @(1)
}

<#
    .SYNOPSIS 
    Builds the current sitefinity instance webapp project file.
    .OUTPUTS
    None
#>
function sf-sol-buildWebAppProj () {
    $context = sf-proj-getCurrent
    $path = "$($context.webAppPath)\SitefinityWebApp.csproj"
    if (!(Test-Path $path)) {
        throw "invalid or no solution or web app project path"
    }

    _buildProj $path
}

function sf-sol-unlockAllFiles {
    $project = sf-proj-getCurrent

    if ($project.solutionPath -ne "") {
        $path = $project.solutionPath
    }
    else {
        $path = $project.webAppPath
    }

    if ($path) {
        unlock-allFiles $path
    }
}
function _buildProj {
    
    Param(
        [Parameter(Mandatory)][string]$path
    )

    if (!(Test-Path $path)) {
        throw "invalid or no proj path"
    }

    Write-Information "Building ${path}"

    if (!(Test-Path $Global:Sf.config.msBuildPath)) {
        throw "Invalid ms build tools path configured $($Global:Sf.config.msBuildPath). Configure it in $Script:userConfigPath -> msBuildPath"
    }

    $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
    $output = Invoke-Expression "& `"$($Global:Sf.config.msBuildPath)`" `"$path`" /nologo /maxcpucount /p:RunCodeAnalysis=False /Verbosity:d"
    $elapsed.Stop()
    
    if ($LastExitCode -ne 0) {
        $errorLogPath = "$Script:moduleUserDir/MsBuild-Errors.log"
        $output | Out-File $errorLogPath
        throw "Build errors occurred. See log at $errorLogPath"
    }
    else {
        Write-Information "Build took $($elapsed.Elapsed.TotalSeconds) second(s)"
    }
}

function _switchStyleCop {
    param (
        [switch]$enable
    )
    
    $context = sf-proj-getCurrent

    $styleCopTaskPath = "$($context.solutionPath)\Builds\StyleCop\StyleCop.Targets"
    $content = Get-Content -Path $styleCopTaskPath
    $newContent = @()
    $foundStyleCopEnabledProperty = $false
    foreach ($line in $content) {
        $foundStyleCopEnabledProperty = $line -match "^.*?\<StyleCopEnabled\>true\<\/StyleCopEnabled\>`$" -or $line -match "^.*?\<StyleCopEnabled\>false\<\/StyleCopEnabled\>`$"
        $foundSourceAnalysisEnabled = $line -match "^.*?\<StyleCopEnabled\>\`$\(SourceAnalysisEnabled\)\<\/StyleCopEnabled\>" -or $line -match "^.*?\<!-- source analysis prop line --\>"
        if ($foundStyleCopEnabledProperty) {
            if ($enable) {
                $newContent += "<StyleCopEnabled>true</StyleCopEnabled>"
            }
            else {
                $newContent += "<StyleCopEnabled>false</StyleCopEnabled>"
            }
        }
        elseif ($foundSourceAnalysisEnabled) {
            if ($enable) {
                $newContent += "<StyleCopEnabled>`$(SourceAnalysisEnabled)</StyleCopEnabled>"
            }
            else {
                $newContent += "<StyleCopEnabled>false</StyleCopEnabled><!-- source analysis prop line -->"
            }
        }
        else {
            $newContent += $line
        }
    }

    _writeFile -content $newContent -path $styleCopTaskPath
}

function _writeFile ($content, $path) {
    $content | Out-File -FilePath $path -Force -Encoding utf8 -ErrorAction Stop
}
