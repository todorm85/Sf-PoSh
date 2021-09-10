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

    $project = sf-PSproject-get

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
    $project = sf-PSproject-get

    $solutionPath = $project.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "Invalid or no solution path."
    }

    sf-sol-unlockAllFiles

    Write-Information "Deleting bins and objs..."
    Get-ChildItem -Path $solutionPath -Force -Recurse -Directory | `
        Where-Object { $_.Name.ToLower() -eq "bin" -or $_.Name.ToLower() -eq "obj" } | `
        Remove-Item -Force -Recurse -ErrorVariable +errorMessage -ErrorAction "Continue"

    if ($errorMessage) {
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

    if ($errorMessage) {
        Write-Error $errorMessage
    }
}

function sf-sol-clearPackages {
    [SfProject]$project = sf-PSproject-get
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
        [switch]$useDefaultName
    )

    $project = sf-PSproject-get

    if (!$project.solutionPath -and !$project.webAppPath) {
        throw "invalid or no solution path and webApp path"
    }

    $path = $project.solutionPath

    if (!$path) {
        $path = $project.webAppPath
        $projectName = "SitefinityWebApp.csproj"
    }
    else {
        if ($useDefaultName) {
            $projectName = "Telerik.Sitefinity.sln"
        }
        else {
            $projectName = _generateCustomSolutionName
        }
    }

    $vsPath = $GLOBAL:sf.config.vsPath
    if (!(Test-Path $vsPath)) {
        throw "Invalid visual studio path configured ($vsPath). Configure it in $($global:sf.config.userConfigPath) -> vsPath or type command sf-config-open"
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
    $context = sf-PSproject-get
    $path = "$($context.webAppPath)\SitefinityWebApp.csproj"
    if (!(Test-Path $path)) {
        throw "invalid or no solution or web app project path"
    }

    _buildProj $path
}

function sf-sol-unlockAllFiles {
    $project = sf-PSproject-get

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

function sf-sol-resetSitefinityFolder {
    [SfProject]$context = sf-PSproject-get
    $webAppPath = $context.webAppPath
    $errorMessage = ''
    Set-Location $context.webAppPath
    if (Test-Path "$webAppPath\App_Data\Sitefinity") {
        $dirs = Get-ChildItem "$webAppPath\App_Data\Sitefinity" | Where-Object { ($_.PSIsContainer -eq $true) -and (( $_.Name -like "Configuration") -or ($_.Name -like "Temp") -or ($_.Name -like "Logs")) }
        try {
            if ($dirs) {
                $dirs | Remove-Item -Force -Recurse -ErrorVariable +errorMessage -ErrorAction SilentlyContinue
            }
        }
        catch {
            $errorMessage = "${errorMessage}`n" + $_
        }
    }

    $errorMessage = $errorMessage | ? {$_ -notlike "\Logs" }
    if ($errorMessage) {
        throw $errorMessage
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

    if (!(Test-Path $GLOBAL:sf.config.msBuildPath)) {
        throw "Invalid ms build tools path configured $($GLOBAL:sf.config.msBuildPath). Configure it in $($global:sf.config.userConfigPath) -> msBuildPath or type sf-config-open"
    }

    $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
    $output = Invoke-Expression "& `"$($GLOBAL:sf.config.msBuildPath)`" `"$path`" /nologo /maxcpucount /p:RunCodeAnalysis=False /Verbosity:d"
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

    $context = sf-PSproject-get

    $styleCopTaskPath = "$($context.solutionPath)\Builds\StyleCop\StyleCop.Targets"
    $content = Get-Content -Path $styleCopTaskPath
    $newContent = @()
    $foundStyleCopEnabledProperty = $false
    foreach ($line in $content) {
        $foundStyleCopEnabledProperty = $line -match "^.*?\<StyleCopEnabled\>true\<\/StyleCopEnabled\>`$" -or $line -match "^.*?\<StyleCopEnabled\>false\<\/StyleCopEnabled\>`$"
        $foundSourceAnalysisEnabled = $line -match "^.*?\<StyleCopEnabled\>\`$\(SourceAnalysisEnabled\)\<\/StyleCopEnabled\>" -or $line -match "^.*?\<!-- source analysis prop line --\>"
        if ($foundStyleCopEnabledProperty) {
            if ($enable) {
                $newContent += "<StyleCopEnabled>`$(SourceAnalysisEnabled)</StyleCopEnabled>"
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
