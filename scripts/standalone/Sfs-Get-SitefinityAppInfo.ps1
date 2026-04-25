<#
.SYNOPSIS
    Returns detailed info about a Sitefinity web application on disk.

.DESCRIPTION
    For the Sitefinity project located at -ProjectRoot:
      1. Resolves the web app folder (the folder containing web.config),
         either -ProjectRoot itself or its 'SitefinityWebApp' subfolder.
      2. Locates the IIS website whose root virtual directory points to
         that folder.
      3. Reads the database name from
         App_Data\Sitefinity\Configuration\DataConfig.config (empty when
         the project has not been initialized yet).
      4. Inspects the IIS site for its application pool, current state,
         bindings and any sub-application path.
      5. Composes one HTTP(S) URL per binding (sub-app path appended when
         present).

    Emits a single object with these properties:
        ProjectRoot, WebAppPath, WebsiteName, DbName,
        AppPool, SiteState, SubAppName,
        Bindings  (Protocol, Port, Domain),
        Urls      (one URL per binding),
        Url       (primary URL = last binding)

    Requirements:
      - Windows + PowerShell 7, run elevated (IIS configuration access).
      - IIS installed (uses Microsoft.Web.Administration directly).

.PARAMETER ProjectRoot
    Path to the Sitefinity project. Either the web app folder itself
    (containing web.config) or a parent solution folder containing a
    'SitefinityWebApp' subfolder.

.EXAMPLE
    pwsh -File .\Sfs-Get-SitefinityAppInfo.ps1 -ProjectRoot 'C:\sites\my-sf'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Sf-Standalone.Common.ps1')

Assert-StandaloneEnvironment

$project  = Resolve-SfProjectInfo -ProjectRoot $ProjectRoot
$bindings = @(Get-IisSiteBindings -WebsiteName $project.WebsiteName)
$subApp   = Get-IisSubAppName    -WebsiteName $project.WebsiteName

$urls = foreach ($b in $bindings) {
    $hostname = if ($b.Domain) { $b.Domain } else { 'localhost' }
    $u = "$($b.Protocol)://${hostname}:$($b.Port)"
    if ($subApp) { $u = "$u/$subApp" }
    $u
}

$sm = [Microsoft.Web.Administration.ServerManager]::new()
try {
    $site    = $sm.Sites[$project.WebsiteName]
    $rootApp = $site.Applications | Where-Object { $_.Path -eq '/' } | Select-Object -First 1
    $appPool = if ($rootApp) { $rootApp.ApplicationPoolName } else { $null }
    $state   = [string]$site.State
}
finally { $sm.Dispose() }

[pscustomobject]@{
    ProjectRoot = $project.ProjectRoot
    WebAppPath  = $project.WebAppPath
    WebsiteName = $project.WebsiteName
    DbName      = $project.DbName
    AppPool     = $appPool
    SiteState   = $state
    SubAppName  = $subApp
    Bindings    = $bindings
    Urls        = @($urls)
    Url         = @($urls) | Select-Object -Last 1
}
