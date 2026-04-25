<#
.SYNOPSIS
    Ensures a Sitefinity web application is running and finished initializing.

.DESCRIPTION
    For the Sitefinity project located at -ProjectRoot:
      1. Locates the IIS website whose root virtual directory points to the
         project's web app folder (the folder containing web.config).
      2. Starts that IIS website if it is stopped.
      3. Verifies that either the project's database (read from
         App_Data\Sitefinity\Configuration\DataConfig.config) exists on the
         given SQL Server, or, if the project has not been initialized yet,
         that a StartupConfig.config is present.
      4. Issues an HTTP request against the site's URL and then polls
         /appstatus until Sitefinity reports it has finished startup, or
         until -TotalWaitSeconds elapses (throws on timeout).

    Requirements:
      - Windows + PowerShell 7, run elevated (IIS configuration access).
      - IIS installed (uses Microsoft.Web.Administration directly).
      - SqlServer PowerShell module (Invoke-Sqlcmd).

.PARAMETER ProjectRoot
    Path to the Sitefinity project. Either the web app folder itself
    (containing web.config) or a parent solution folder containing a
    'SitefinityWebApp' subfolder.

.PARAMETER SqlServerInstance
    SQL Server instance used to verify the project database exists.

.PARAMETER SqlUser
    SQL Server login.

.PARAMETER SqlPassword
    Password for -SqlUser.

.PARAMETER TotalWaitSeconds
    Maximum number of seconds to wait for Sitefinity to finish initializing.
    Defaults to 180.

.EXAMPLE
    pwsh -File .\Sfs-EnsureRunning-SitefinityApp.ps1 `
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
if (-not $project.WebsiteName) {
    throw "No IIS website is bound to '$($project.WebAppPath)'. Create one first (see Sfs-Create-SitefinityAppIisSite.ps1)."
}
Invoke-SfAppEnsureRunning -Project $project `
    -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword `
    -TotalWaitSeconds $TotalWaitSeconds
