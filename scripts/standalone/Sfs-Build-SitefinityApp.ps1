<#
.SYNOPSIS
    Builds a Sitefinity solution (or just the SitefinityWebApp.csproj when
    no solution file is present), with optional package restore, clean,
    package cache wipe, and retry support. Long-running (typically several
    minutes, especially with -Restore / -CleanPackages); the MCP server
    emits notifications/progress while it runs, so do NOT retry on an
    apparent client-side timeout.

.DESCRIPTION
    For the Sitefinity project located at -ProjectRoot:
      1. Resolves the solution folder. -ProjectRoot may be either the web
         app folder itself (containing web.config) or a parent solution
         folder containing a 'SitefinityWebApp' subfolder.
      2. Picks the build target:
           a. <solutionRoot>\Telerik.Sitefinity.sln  (preferred), or
           b. <solutionRoot>\Telerik.Sitefinity.slnx, or
           c. <webAppPath>\SitefinityWebApp.csproj when neither exists.
      3. Optionally cleans first (-Clean): unlocks files, deletes every
         'bin' and 'obj' folder under the solution root, deletes
         <webAppPath>\ResourcePackages.
      4. Optionally wipes the NuGet package cache (-CleanPackages):
         deletes <solutionRoot>\packages\*.
      5. Optionally restores packages before building (-Restore). Mixed
         projects are common, so the script always combines both:
           - For every packages.config under the solution root, runs
             "<NuGet> restore <packages.config> -SolutionDirectory <root>"
             (handles old-style projects).
           - Passes /restore to MSBuild (handles PackageReference, .slnx,
             SDK-style projects).
      6. Invokes MSBuild on the chosen target with /maxcpucount,
         /p:RunCodeAnalysis=False, /v:q. On failure retries up to
         -RetryCount times.

    Requirements:
      - Windows + PowerShell 7.
      - MSBuild.exe auto-discovered via vswhere or PATH.
      - nuget.exe auto-discovered via PATH or downloaded into
        `$env:LOCALAPPDATA\Sfs-Tools\nuget.exe` (only when -Restore is set).

.PARAMETER ProjectRoot
    Path to the Sitefinity project. Either the web app folder itself
    (containing web.config) or a parent solution folder containing a
    'SitefinityWebApp' subfolder. Defaults to $env:SF_PROJECT_ROOT;
    required if the env var is unset.

.PARAMETER Restore
    Restore NuGet packages before building (see DESCRIPTION for details).

.PARAMETER Clean
    Delete every bin/obj folder under the solution root and remove
    <webAppPath>\ResourcePackages before building.

.PARAMETER CleanPackages
    Wipe <solutionRoot>\packages before building. Implies a fresh restore
    is needed if the build references package binaries.

.PARAMETER RetryCount
    Number of additional build attempts after the first failure.
    Default: 0 (build runs once).

.EXAMPLE
    pwsh -File .\Sfs-Build-SitefinityApp.ps1 -ProjectRoot 'C:\sites\my-sf'

.EXAMPLE
    pwsh -File .\Sfs-Build-SitefinityApp.ps1 `
        -ProjectRoot 'C:\sites\my-sf' `
        -Clean -CleanPackages -Restore -RetryCount 2
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = $(if ($env:SF_PROJECT_ROOT) { $env:SF_PROJECT_ROOT } else { throw 'ProjectRoot not provided and $env:SF_PROJECT_ROOT is not set.' }),
    [switch]$Restore,
    [switch]$Clean,
    [switch]$CleanPackages,
    [int]$RetryCount = 0
)

$ErrorActionPreference = 'Stop'

if (-not $IsWindows) { throw "This script requires Windows." }
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "This script requires PowerShell 7 or later. Current: $($PSVersionTable.PSVersion)"
}

if (-not (Test-Path $ProjectRoot)) {
    throw "Project root not found: '$ProjectRoot'."
}
$ProjectRoot = (Resolve-Path $ProjectRoot).Path

# Resolve web app path + solution root.
$webAppPath = $null
$solutionRoot = $null

if (Test-Path (Join-Path $ProjectRoot 'web.config')) {
    $webAppPath   = $ProjectRoot
    # Solution likely sits one level up (where Telerik.Sitefinity.sln lives).
    $parent = Split-Path $ProjectRoot -Parent
    if ($parent -and (
            (Test-Path (Join-Path $parent 'Telerik.Sitefinity.sln')) -or
            (Test-Path (Join-Path $parent 'Telerik.Sitefinity.slnx'))
        )) {
        $solutionRoot = $parent
    }
    else {
        # Web-app-only project (no surrounding solution folder).
        $solutionRoot = $ProjectRoot
    }
}
elseif (Test-Path (Join-Path $ProjectRoot 'SitefinityWebApp\web.config')) {
    $webAppPath   = (Join-Path $ProjectRoot 'SitefinityWebApp')
    $solutionRoot = $ProjectRoot
}
else {
    throw "Could not locate Sitefinity web app under '$ProjectRoot'. Expected 'web.config' there or under 'SitefinityWebApp'."
}

# Pick build target.
$slnPath  = Join-Path $solutionRoot 'Telerik.Sitefinity.sln'
$slnxPath = Join-Path $solutionRoot 'Telerik.Sitefinity.slnx'
$csprojPath = Join-Path $webAppPath 'SitefinityWebApp.csproj'

if (Test-Path $slnPath)        { $buildTarget = $slnPath }
elseif (Test-Path $slnxPath)   { $buildTarget = $slnxPath }
elseif (Test-Path $csprojPath) { $buildTarget = $csprojPath }
else {
    throw "Found no build target. Expected one of: '$slnPath', '$slnxPath', or '$csprojPath'."
}

function _resolveMsBuild {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $found = & $vswhere -latest -prerelease -products * `
            -requires Microsoft.Component.MSBuild `
            -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null |
            Select-Object -First 1
        if ($found -and (Test-Path $found)) { return $found }
    }

    $cmd = Get-Command MSBuild.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    throw "Could not auto-discover MSBuild.exe. Install Visual Studio / MSBuild Build Tools, or add MSBuild.exe to PATH."
}

function _resolveNuGet {
    $cmd = Get-Command nuget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $cacheDir = Join-Path $env:LOCALAPPDATA 'Sfs-Tools'
    $cached   = Join-Path $cacheDir 'nuget.exe'
    if (Test-Path $cached) { return $cached }

    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir | Out-Null
    }
    $url = 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe'
    Write-Information "Downloading nuget.exe from $url -> $cached" -InformationAction Continue
    Invoke-WebRequest -Uri $url -OutFile $cached -UseBasicParsing
    return $cached
}

$MsBuildPath = _resolveMsBuild
Write-Information "Using MSBuild: $MsBuildPath" -InformationAction Continue

if ($Restore) {
    $NuGetPath = _resolveNuGet
    Write-Information "Using nuget.exe: $NuGetPath" -InformationAction Continue
}

function _unlockAllFiles([string]$root) {
    Get-ChildItem -Path $root -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.IsReadOnly } |
        ForEach-Object {
            try { $_.IsReadOnly = $false } catch { }
        }
}

function _doClean {
    Write-Information "Cleaning solution under '$solutionRoot'..." -InformationAction Continue
    _unlockAllFiles $solutionRoot

    Get-ChildItem -Path $solutionRoot -Force -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq 'bin' -or $_.Name -ieq 'obj' } |
        Remove-Item -Force -Recurse -ErrorAction Continue

    $resourcePackages = Join-Path $webAppPath 'ResourcePackages'
    if (Test-Path $resourcePackages) {
        Remove-Item $resourcePackages -Force -Recurse -ErrorAction Continue
    }
}

function _doCleanPackages {
    $packages = Join-Path $solutionRoot 'packages'
    if (-not (Test-Path $packages)) {
        Write-Information "No packages folder at '$packages'." -InformationAction Continue
        return
    }

    Write-Information "Removing '$packages'\*..." -InformationAction Continue
    Get-ChildItem $packages -Directory | Remove-Item -Force -Recurse -ErrorAction Continue
}

function _doRestore {
    # Mirror the historical sf-buildProj behavior: ALWAYS run nuget for
    # any packages.config (covers legacy projects) and ALSO let MSBuild
    # restore (covers PackageReference / SDK-style / .slnx). Solutions
    # often mix both styles, so doing both is the safe default.
    $configs = @(Get-ChildItem $solutionRoot -Recurse -Filter 'packages.config' -ErrorAction SilentlyContinue)
    foreach ($c in $configs) {
        Write-Information "nuget restore '$($c.FullName)'" -InformationAction Continue
        & $NuGetPath restore $c.FullName -SolutionDirectory $solutionRoot
        if ($LASTEXITCODE -ne 0) { throw "nuget restore failed for '$($c.FullName)' (exit $LASTEXITCODE)." }
    }
}

function _doBuild {
    Write-Information "Building '$buildTarget'..." -InformationAction Continue
    $args = @($buildTarget, '/nologo', '/maxcpucount', '/p:RunCodeAnalysis=False', '/v:q')
    if ($Restore) { $args += '/restore' }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $MsBuildPath @args
    $exit = $LASTEXITCODE
    $sw.Stop()
    Write-Information "Build took $([int]$sw.Elapsed.TotalSeconds) second(s) (exit $exit)." -InformationAction Continue

    if ($exit -ne 0) { throw "MSBuild failed (exit $exit) for '$buildTarget'." }
}

if ($Clean)         { _doClean }
if ($CleanPackages) { _doCleanPackages }
if ($Restore)       { _doRestore }

$attempts = 0
while ($true) {
    try {
        _doBuild
        break
    }
    catch {
        $attempts++
        if ($attempts -gt $RetryCount) { throw }
        Write-Warning "Build failed (attempt $attempts of $($RetryCount + 1)). Retrying... $_"
    }
}
