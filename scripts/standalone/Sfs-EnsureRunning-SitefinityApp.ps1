<#
.SYNOPSIS
    Ensures a Sitefinity web application is running and finished initializing.

.DESCRIPTION
    For the Sitefinity project located at -ProjectRoot:
      1. Locates the IIS website whose root virtual directory points to the
         project's web app folder (the folder containing web.config).
      2. Starts that IIS website if it is stopped.
      3. Polls /appstatus until Sitefinity reports it has finished startup,
         or until -TotalWaitSeconds elapses (throws on timeout).

    Requirements:
      - Windows + PowerShell 7, run elevated (IIS configuration access).
      - IIS installed (uses Microsoft.Web.Administration directly).

.PARAMETER ProjectRoot
    Path to the Sitefinity project. Either the web app folder itself
    (containing web.config) or a parent solution folder containing a
    'SitefinityWebApp' subfolder. Defaults to $env:SF_PROJECT_ROOT;
    required if the env var is unset.

.PARAMETER TotalWaitSeconds
    Maximum number of seconds to wait for Sitefinity to finish initializing.
    Defaults to 180.

.EXAMPLE
    pwsh -File .\Sfs-EnsureRunning-SitefinityApp.ps1 -ProjectRoot 'C:\sites\my-sf'
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
