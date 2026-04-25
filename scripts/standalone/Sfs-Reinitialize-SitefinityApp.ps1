<#
.SYNOPSIS
    Standalone equivalent of sf-app-reinitialize.

.DESCRIPTION
    Recycles the IIS app pool, drops the current Sitefinity database (if any),
    clears App_Data\Sitefinity\{Configuration,Temp,Logs}, writes a fresh
    StartupConfig.config and (unless -SkipEnsureRunning) waits for the app
    to finish initializing.

    Requires Windows + PowerShell 7 + WebAdministration + SqlServer modules.

.EXAMPLE
    pwsh -File .\Sf-App-Reinitialize.ps1 `
        -ProjectRoot 'C:\sites\my-sf' `
        -SqlServerInstance '.' -SqlUser 'sa' -SqlPassword 'pw' `
        -SitefinityUser 'admin@test.test' -SitefinityPassword 'pw'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [Parameter(Mandatory)][string]$SqlServerInstance,
    [Parameter(Mandatory)][string]$SqlUser,
    [Parameter(Mandatory)][string]$SqlPassword,
    [Parameter(Mandatory)][string]$SitefinityUser,
    [Parameter(Mandatory)][string]$SitefinityPassword,
    [string]$DbName,
    [int]$TotalWaitSeconds = 180,
    [switch]$SkipEnsureRunning
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Sf-Standalone.Common.ps1')

Assert-StandaloneEnvironment

$project = Resolve-SfProjectInfo -ProjectRoot $ProjectRoot
Invoke-SfAppReinitialize -Project $project `
    -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword `
    -SitefinityUser $SitefinityUser -SitefinityPassword $SitefinityPassword `
    -DbName $DbName -TotalWaitSeconds $TotalWaitSeconds -SkipEnsureRunning:$SkipEnsureRunning
