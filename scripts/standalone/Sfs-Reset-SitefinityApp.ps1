<#
.SYNOPSIS
    Resets a Sitefinity web application: uninitializes it and then
    re-initializes it against a fresh database.

.DESCRIPTION
    For the Sitefinity project located at -ProjectRoot:
      1. Locates the IIS website whose root virtual directory points to the
         project's web app folder (the folder containing web.config) and
         recycles its application pool.
      2. Optionally (when -DeleteOldDatabase is supplied) reads the database
         name from App_Data\Sitefinity\Configuration\DataConfig.config and
         drops that database from the given SQL Server.
      3. Deletes App_Data\Sitefinity\Configuration, Temp and Logs (this
         leaves the project in an uninitialized state).
      4. Drops -DbName from SQL Server if it already exists.
      5. Writes a fresh App_Data\Sitefinity\Configuration\StartupConfig.config
         instructing Sitefinity, on next startup, to create database
         -DbName on the given SQL Server and provision an admin user with
         -SitefinityUser / -SitefinityPassword.
      6. Unless -SkipEnsureRunning is supplied, starts the IIS site and
         polls /appstatus until Sitefinity finishes initializing, or until
         -TotalWaitSeconds elapses (throws on timeout).

    Requirements:
      - Windows + PowerShell 7, run elevated (IIS configuration access).
      - IIS installed (uses Microsoft.Web.Administration directly).
      - SqlServer PowerShell module (Invoke-Sqlcmd).

.PARAMETER ProjectRoot
    Path to the Sitefinity project. Either the web app folder itself
    (containing web.config) or a parent solution folder containing a
    'SitefinityWebApp' subfolder.

.PARAMETER SqlServerInstance
    SQL Server instance to drop databases from and that Sitefinity will
    use to create the new DB.

.PARAMETER SqlUser
    SQL Server login (also written into StartupConfig.config so Sitefinity
    can create the new database).

.PARAMETER SqlPassword
    Password for -SqlUser.

.PARAMETER SitefinityUser
    Email/username of the Sitefinity admin user to be provisioned during
    initialization.

.PARAMETER SitefinityPassword
    Password for the Sitefinity admin user.

.PARAMETER DbName
    Name of the SQL Server database to (re)create for this Sitefinity
    project. Will be dropped first if it already exists.

.PARAMETER DeleteOldDatabase
    Also drop the database currently recorded in DataConfig.config (the
    project's previous DB). Has no effect when there is no DataConfig.
    Implicitly enabled when -DbName matches the previous DB name (the old
    database must be dropped before re-initializing on the same name).

.PARAMETER TotalWaitSeconds
    Maximum number of seconds to wait for Sitefinity to finish initializing
    after restart. Defaults to 180.

.PARAMETER SkipEnsureRunning
    Skip the post-restart readiness wait. The site is left to be started
    on first request.

.EXAMPLE
    pwsh -File .\Sfs-Reset-SitefinityApp.ps1 `
        -ProjectRoot 'C:\sites\my-sf' `
        -SqlServerInstance '.' -SqlUser 'sa' -SqlPassword 'pw' `
        -SitefinityUser 'admin@test.test' -SitefinityPassword 'pw' `
        -DbName 'my-sf'

.EXAMPLE
    pwsh -File .\Sfs-Reset-SitefinityApp.ps1 `
        -ProjectRoot 'C:\sites\my-sf' `
        -SqlServerInstance '.' -SqlUser 'sa' -SqlPassword 'pw' `
        -SitefinityUser 'admin@test.test' -SitefinityPassword 'pw' `
        -DbName 'my-sf' -DeleteOldDatabase
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [Parameter(Mandatory)][string]$SqlServerInstance,
    [Parameter(Mandatory)][string]$SqlUser,
    [Parameter(Mandatory)][string]$SqlPassword,
    [Parameter(Mandatory)][string]$SitefinityUser,
    [Parameter(Mandatory)][string]$SitefinityPassword,
    [Parameter(Mandatory)][string]$DbName,
    [switch]$DeleteOldDatabase,
    [int]$TotalWaitSeconds = 180,
    [switch]$SkipEnsureRunning
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Sf-Standalone.Common.ps1')

Assert-StandaloneEnvironment

$project = Resolve-SfProjectInfo -ProjectRoot $ProjectRoot
if (-not $project.WebsiteName) {
    throw "No IIS website is bound to '$($project.WebAppPath)'. Create one first (see Sfs-Create-SitefinityAppIisSite.ps1)."
}

# --- Uninitialize ---------------------------------------------------------
Reset-IisAppPoolForSite -WebsiteName $project.WebsiteName

$oldDb = Get-SfDbNameFromDataConfig -WebAppPath $project.WebAppPath

# If reusing the same DB name, the old DB must be dropped or the next init
# will fail. Treat that case as -DeleteOldDatabase implicitly.
if ($oldDb -and $oldDb -ieq $DbName) {
    $DeleteOldDatabase = $true
}

if ($DeleteOldDatabase) {
    if ($oldDb) {
        Remove-SqlDatabaseIfExists -DbName $oldDb `
            -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword
    }
    else {
        Write-Verbose "No database name found in DataConfig.config; nothing to drop."
    }
}

Reset-SitefinityAppDataFolder -WebAppPath $project.WebAppPath

# --- Initialize -----------------------------------------------------------
Invoke-SfAppInitialize -Project $project `
    -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword `
    -SitefinityUser $SitefinityUser -SitefinityPassword $SitefinityPassword `
    -DbName $DbName -TotalWaitSeconds $TotalWaitSeconds -SkipEnsureRunning:$SkipEnsureRunning
