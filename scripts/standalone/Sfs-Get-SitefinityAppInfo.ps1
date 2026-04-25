<#
.SYNOPSIS
    Returns detailed info for a Sitefinity project at a given path.

.DESCRIPTION
    Resolves the web app folder under -ProjectRoot, finds the IIS website
    that points to it, reads DataConfig.config to determine the database
    name (if configured), and emits an object with:
        ProjectRoot, WebAppPath, WebsiteName, DbName,
        AppPool, SiteState, SubAppName,
        Bindings  (Protocol, Port, Domain),
        Urls      (one URL per binding, sub-app appended when present),
        Url       (primary URL)

    Requires Windows + PowerShell 7 + IIS (Microsoft.Web.Administration).

.EXAMPLE
    pwsh -File .\Sfs-Get-ProjectInfo.ps1 -ProjectRoot 'C:\sites\my-sf'
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
