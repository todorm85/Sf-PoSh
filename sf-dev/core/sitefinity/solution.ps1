<#
    .SYNOPSIS 
    Builds the current sitefinity instance solution.
    .OUTPUTS
    None
#>
function Build-Solution {
    
    Param(
        $retryCount = 0,
        [SfProject]$project
    )
    
    if (!$project) {
        $project = Get-CurrentProject
    }

    $solutionPath = "$($project.solutionPath)\Telerik.Sitefinity.sln"
    
    $tries = 0
    $isBuilt = $false
    while ($tries -le $retryCount -and (-not $isBuilt)) {
        try {
            if (!(Test-Path $solutionPath)) {
                Build-WebAppProj
            }
            else {
                try {
                    Switch-StyleCop -context $project -enable:$false
                    build-proj_ $solutionPath
                }
                finally {
                    Switch-StyleCop -context $project -enable:$true
                }
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
function Rebuild-Solution {
    
    Param(
        [bool]$cleanPackages = $false,
        $retryCount = 0,
        [SfProject]$project)
    
    if (!$project) {
        $project = Get-CurrentProject
    }

    Write-Information "Rebuilding solution..."
    try {
        Clean-Solution -cleanPackages $cleanPackages -project $project
    }
    catch {
        Write-Warning "Errors while cleaning solution: $_"
    }

    Build-Solution -retryCount $retryCount -project $project
}

function Clean-Solution {
    Param(
        [bool]$cleanPackages = $false,
        [SfProject]$project)

    Write-Information "Cleaning solution..."
    if (!$project) {
        $project = Get-CurrentProject
    }

    $solutionPath = $project.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

     Unlock-AllProjectFiles -project $project

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
            Clean-Packages -project $project
        }
        catch {
            $errorMessage = "$errorMessage`nErrors while deleting packages:`n" + $_
        }
    }

    if ($errorMessage -ne '') {
        throw $errorMessage
    }
}

function Clean-Packages {
    Param(
        [SfProject]$project
    )

    if (!$project) {
        $project = Get-CurrentProject
    }

    if (!(Test-Path "${solutionPath}\packages")) {
        Write-Warning "No packages to delete"
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
function Open-Solution {
    
    Param(
        [switch]$useDefault,
        [SfProject]$project
    )
    if (!$project) {
        $project = Get-CurrentProject
    }
    
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
            $projectName = generate-solutionFriendlyName_
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
function Build-WebAppProj () {
    

    $context = Get-CurrentProject
    $path = "$($context.webAppPath)\SitefinityWebApp.csproj"
    if (!(Test-Path $path)) {
        throw "invalid or no solution or web app project path"
    }

    build-proj_ $path
}

function  Unlock-AllProjectFiles {
    Param(
        [SfProject]$project
    )

    if (!$project) {
        $project = Get-CurrentProject
    }

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
function build-proj_ {
    
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

function Switch-StyleCop {
    param (
        [SfProject]$context,
        [switch]$enable
    )
    
    if (-not $context) {
        $context = Get-CurrentProject
    }

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

    write-File_ -content $newContent -path $styleCopTaskPath
}

function write-File_ ($content, $path) {
    $content | Out-File -FilePath $path -Force -Encoding utf8 -ErrorAction Stop
}
