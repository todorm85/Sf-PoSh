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

if (Get-Website -Name $Name -ErrorAction SilentlyContinue) {
    throw "IIS website '$Name' already exists."
}
if (Get-ChildItem 'IIS:\AppPools' | Where-Object { $_.Name -eq $Name }) {
    throw "IIS application pool '$Name' already exists."
}

function _isPortFree {
    param([int]$Port)
    $boundInIis = @(Get-WebBinding | Select-Object -Expand bindingInformation |
        ForEach-Object { $_.Split(':')[1] } | Where-Object { [int]$_ -eq $Port })
    if ($boundInIis.Count -gt 0) { return $false }
    $listening = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPort -eq $Port })
    return $listening.Count -eq 0
}

if (-not $Port) {
    $candidatePort = Get-Random -Minimum 49152 -Maximum 65535
    while (-not (_isPortFree -Port $candidatePort)) { $candidatePort++ }
    $Port = $candidatePort
}
elseif (-not (_isPortFree -Port $Port)) {
    throw "Port $Port is already in use."
}

# App pool
$poolPath = "IIS:\AppPools\$Name"
New-Item $poolPath | Out-Null
Set-ItemProperty $poolPath -Name 'processModel.idleTimeout' -Value ([TimeSpan]::FromMinutes(0))

# Website
New-Item ("IIS:\Sites\$Name") `
    -bindings @{ protocol = 'http'; bindingInformation = "*:${Port}:" } `
    -physicalPath $webAppPath |
    Set-ItemProperty -Name 'applicationPool' -Value $Name | Out-Null

if ($Domain) {
    New-WebBinding -Name $Name -Protocol http -Port $Port -HostHeader $Domain | Out-Null

    $hostsPath = Join-Path $env:WINDIR 'System32\drivers\etc\hosts'
    $entry = "127.0.0.1 $Domain"
    if ((Get-Content $hostsPath) -notcontains $entry) {
        Add-Content -Encoding utf8 $hostsPath $entry
    }
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
    WebsiteName = $Name
    AppPool     = $Name
    Port        = $Port
    Domain      = $Domain
    PhysicalPath = $webAppPath
}
