<#
.SYNOPSIS
    Standalone equivalent of sf-app-ensureRunning.

.DESCRIPTION
    Verifies that the IIS site for a Sitefinity project is started, that its
    database (or a StartupConfig fallback) is present, and then polls
    /appstatus until Sitefinity reports it has finished initializing.

    Requires Windows + PowerShell 7 + WebAdministration + SqlServer modules.

.EXAMPLE
    pwsh -File .\Sf-App-EnsureRunning.ps1 `
        -ProjectRoot 'C:\sites\my-sf' `
        -SqlServerInstance '.' -SqlUser 'sa' -SqlPassword 'pw'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [Parameter(Mandatory)][string]$SqlServerInstance,
    [Parameter(Mandatory)][string]$SqlUser,
    [Parameter(Mandatory)][string]$SqlPassword,
    [int]$TotalWaitSeconds = 180
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Sf-Standalone.Common.ps1')

Assert-StandaloneEnvironment

$project = Resolve-SfProjectInfo -ProjectRoot $ProjectRoot
Invoke-SfAppEnsureRunning -Project $project `
    -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword `
    -TotalWaitSeconds $TotalWaitSeconds
