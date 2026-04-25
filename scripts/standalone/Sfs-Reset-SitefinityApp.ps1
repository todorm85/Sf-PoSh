<#
.SYNOPSIS
    Resets a Sitefinity app: recycles the app pool, clears App_Data
    (Configuration, Temp, Logs), and optionally drops the database.

.DESCRIPTION
    Standalone equivalent of sf-app-uninitialize. By default the database
    is NOT touched. Pass -DeleteDatabase to also drop the database
    referenced by DataConfig.config (if any). When -DeleteDatabase is
    used, -SqlServerInstance / -SqlUser / -SqlPassword become mandatory.

    Requires Windows + PowerShell 7 (run elevated) + SqlServer module
    (only when -DeleteDatabase is used).

.EXAMPLE
    pwsh -File .\Sfs-Reset-SitefinityApp.ps1 -ProjectRoot 'C:\sites\my-sf'

.EXAMPLE
    pwsh -File .\Sfs-Reset-SitefinityApp.ps1 -ProjectRoot 'C:\sites\my-sf' `
        -DeleteDatabase -SqlServerInstance '.' -SqlUser 'sa' -SqlPassword 'pw'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [switch]$DeleteDatabase,
    [string]$SqlServerInstance,
    [string]$SqlUser,
    [string]$SqlPassword
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Sf-Standalone.Common.ps1')

Assert-StandaloneEnvironment

if ($DeleteDatabase) {
    foreach ($p in 'SqlServerInstance','SqlUser','SqlPassword') {
        if (-not $PSBoundParameters.ContainsKey($p) -or [string]::IsNullOrEmpty((Get-Variable $p -ValueOnly))) {
            throw "-$p is required when -DeleteDatabase is specified."
        }
    }
}

$project = Resolve-SfProjectInfo -ProjectRoot $ProjectRoot

Reset-IisAppPoolForSite -WebsiteName $project.WebsiteName

if ($DeleteDatabase) {
    $dbName = Get-SfDbNameFromDataConfig -WebAppPath $project.WebAppPath
    if ($dbName) {
        Remove-SqlDatabaseIfExists -DbName $dbName `
            -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword
    }
    else {
        Write-Verbose "No database name found in DataConfig.config; nothing to drop."
    }
}

Reset-SitefinityAppDataFolder -WebAppPath $project.WebAppPath
