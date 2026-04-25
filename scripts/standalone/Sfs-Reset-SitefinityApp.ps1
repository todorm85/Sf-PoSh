<#
.SYNOPSIS
    Resets a Sitefinity web application: recycles its IIS app pool and
    clears its runtime App_Data folders. Optionally also drops its database.

.DESCRIPTION
    For the Sitefinity project located at -ProjectRoot:
      1. Locates the IIS website whose root virtual directory points to the
         project's web app folder (the folder containing web.config) and
         recycles its application pool.
      2. Optionally (when -DeleteDatabase is supplied) reads the database
         name from App_Data\Sitefinity\Configuration\DataConfig.config and
         drops that database from the given SQL Server. If no DataConfig
         exists, no database action is taken.
      3. Deletes App_Data\Sitefinity\Configuration, Temp and Logs.

    After this script runs the project is in an uninitialized state: the
    next startup will require a StartupConfig.config (see
    Sfs-Reinitialize-SitefinityApp.ps1) to provision a fresh database.

    Requirements:
      - Windows + PowerShell 7, run elevated (IIS configuration access).
      - IIS installed (uses Microsoft.Web.Administration directly).
      - SqlServer PowerShell module (only when -DeleteDatabase is used).

.PARAMETER ProjectRoot
    Path to the Sitefinity project. Either the web app folder itself
    (containing web.config) or a parent solution folder containing a
    'SitefinityWebApp' subfolder.

.PARAMETER DeleteDatabase
    Also drop the database recorded in DataConfig.config from the SQL
    Server. When supplied, -SqlServerInstance / -SqlUser / -SqlPassword
    become required.

.PARAMETER SqlServerInstance
    SQL Server instance hosting the database to drop. Required only with
    -DeleteDatabase.

.PARAMETER SqlUser
    SQL Server login. Required only with -DeleteDatabase.

.PARAMETER SqlPassword
    Password for -SqlUser. Required only with -DeleteDatabase.

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
