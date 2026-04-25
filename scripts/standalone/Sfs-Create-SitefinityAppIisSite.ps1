<#
.SYNOPSIS
    Standalone equivalent of sf-iis-site-new: creates an IIS website + app pool
    for a Sitefinity project on disk.

.DESCRIPTION
    Creates a dedicated IIS application pool and website pointing to the
    project's Sitefinity web app folder, with permissions for the new app
    pool identity. Optionally adds a hosts-file entry for a custom domain.

    Requires Windows + PowerShell 7 + WebAdministration. Run as Administrator.

.PARAMETER ProjectRoot
    Path to the Sitefinity project. Either the web app folder itself
    (containing web.config) or a parent solution folder containing a
    SitefinityWebApp subfolder.

.PARAMETER Name
    Name to use for the new IIS website AND application pool. Must be unique
    in IIS.

.PARAMETER Port
    Port to bind on. If omitted, the first free TCP/HTTP port >= 49152 is
    picked.

.PARAMETER Domain
    Optional host header. When provided it is also added to the Windows
    hosts file as 127.0.0.1.

.EXAMPLE
    pwsh -File .\Sf-Site-New.ps1 -ProjectRoot 'C:\sitefinities\my-sf' -Name 'my-sf'

.EXAMPLE
    pwsh -File .\Sf-Site-New.ps1 -ProjectRoot 'C:\sitefinities\my-sf' -Name 'my-sf' -Port 8080 -Domain 'my-sf.local'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [Parameter(Mandatory)][string]$Name,
    [int]$Port,
    [string]$Domain
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Sf-Standalone.Common.ps1')

Assert-StandaloneEnvironment

# Resolve the web app folder (without requiring the site to already exist).
if (-not (Test-Path $ProjectRoot)) {
    throw "Project root path not found: '$ProjectRoot'."
}
$ProjectRoot = (Resolve-Path $ProjectRoot).Path

$candidate = Join-Path $ProjectRoot 'SitefinityWebApp'
if (Test-Path (Join-Path $ProjectRoot 'web.config')) {
    $webAppPath = $ProjectRoot
}
elseif (Test-Path (Join-Path $candidate 'web.config')) {
    $webAppPath = (Resolve-Path $candidate).Path
}
else {
    throw "Could not locate Sitefinity web app under '$ProjectRoot'. Expected a 'web.config' there or under a 'SitefinityWebApp' subfolder."
}

$existingSite = Find-IisSiteByPhysicalPath -PhysicalPath $webAppPath
if ($existingSite) {
    throw "IIS website '$existingSite' already points to web app path '$webAppPath'."
}

$sm = [Microsoft.Web.Administration.ServerManager]::new()
try {
    if ($sm.Sites[$Name])            { throw "IIS website '$Name' already exists." }
    if ($sm.ApplicationPools[$Name]) { throw "IIS application pool '$Name' already exists." }

    $usedIisPorts = @()
    foreach ($s in $sm.Sites) {
        foreach ($b in $s.Bindings) {
            $p = ([string]$b.BindingInformation).Split(':')[1]
            if ($p) { $usedIisPorts += [int]$p }
        }
    }

    function _isPortFree {
        param([int]$Port, [int[]]$Used)
        if ($Used -contains $Port) { return $false }
        $listening = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            Where-Object { $_.LocalPort -eq $Port })
        return $listening.Count -eq 0
    }

    if (-not $Port) {
        $candidatePort = Get-Random -Minimum 49152 -Maximum 65535
        while (-not (_isPortFree -Port $candidatePort -Used $usedIisPorts)) { $candidatePort++ }
        $Port = $candidatePort
    }
    elseif (-not (_isPortFree -Port $Port -Used $usedIisPorts)) {
        throw "Port $Port is already in use."
    }

    # App pool
    $pool = $sm.ApplicationPools.Add($Name)
    $pool.ProcessModel.IdleTimeout = [TimeSpan]::Zero

    # Website
    $bindingInfo = "*:${Port}:"
    $site = $sm.Sites.Add($Name, 'http', $bindingInfo, $webAppPath)
    $site.Applications['/'].ApplicationPoolName = $Name

    if ($Domain) {
        $site.Bindings.Add("*:${Port}:$Domain", 'http') | Out-Null

        $hostsPath = Join-Path $env:WINDIR 'System32\drivers\etc\hosts'
        $entry = "127.0.0.1 $Domain"
        if ((Get-Content $hostsPath) -notcontains $entry) {
            Add-Content -Encoding utf8 $hostsPath $entry
        }
    }

    $sm.CommitChanges()
}
finally {
    $sm.Dispose()
}

# Grant app pool identity full control on the web app folder
$acl = Get-Acl $webAppPath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "IIS AppPool\$Name",
    'Full',
    'ContainerInherit,ObjectInherit',
    'None',
    'Allow')
$acl.SetAccessRule($rule)
Set-Acl -Path $webAppPath -AclObject $acl

[pscustomobject]@{
    WebsiteName  = $Name
    AppPool      = $Name
    Port         = $Port
    Domain       = $Domain
    PhysicalPath = $webAppPath
}
