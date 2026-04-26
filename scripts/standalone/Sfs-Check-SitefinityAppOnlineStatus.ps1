<#
.SYNOPSIS
    Checks that a Sitefinity web application is online and finished
    initializing. May be long-running on a cold start (up to
    -TotalWaitSeconds, default 180s); the MCP server emits
    notifications/progress while it polls, so do NOT retry on an
    apparent client-side timeout.

.DESCRIPTION
    For the Sitefinity project located at -ProjectRoot:
      1. Locates the IIS website whose root virtual directory points to the
         project's web app folder (the folder containing web.config).
      2. Starts that IIS website if it is stopped (so the status check has
         something to talk to).
      3. Polls /appstatus until Sitefinity reports it has finished startup
         (i.e. is online), or until -TotalWaitSeconds elapses (throws on
         timeout).

    Returns successfully once the app is confirmed online; throws if it does
    not come online within the wait window.

    Requirements:
      - Windows + PowerShell 7, run elevated (IIS configuration access).
      - IIS installed (uses Microsoft.Web.Administration directly).

.PARAMETER ProjectRoot
    Path to the Sitefinity project. Either the web app folder itself
    (containing web.config) or a parent solution folder containing a
    'SitefinityWebApp' subfolder. Defaults to $env:SF_PROJECT_ROOT;
    required if the env var is unset.

.PARAMETER TotalWaitSeconds
    Maximum number of seconds to wait for Sitefinity to come online.
    Defaults to 180.

.EXAMPLE
    pwsh -File .\Sfs-Check-SitefinityAppOnlineStatus.ps1 -ProjectRoot 'C:\sites\my-sf'
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = $(if ($env:SF_PROJECT_ROOT) { $env:SF_PROJECT_ROOT } else { throw 'ProjectRoot not provided and $env:SF_PROJECT_ROOT is not set.' }),
    [int]$TotalWaitSeconds = 180
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Sf-Standalone.Common.ps1')

Assert-StandaloneEnvironment

$project = Resolve-SfProjectInfo -ProjectRoot $ProjectRoot
if (-not $project.WebsiteName) {
    throw "No IIS website is bound to '$($project.WebAppPath)'. Create one first (see Sfs-Create-SitefinityAppIisSite.ps1)."
}

Invoke-SfAppEnsureRunning -Project $project -TotalWaitSeconds $TotalWaitSeconds
