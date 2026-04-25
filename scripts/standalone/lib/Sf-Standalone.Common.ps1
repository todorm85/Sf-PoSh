<#
.SYNOPSIS
    Shared helpers for the standalone Sitefinity app scripts.

.DESCRIPTION
    Behavior-equivalent extraction of the parts of Sf-PoSh needed by
    sf-app-ensureRunning and sf-app-reinitialize, refactored to take
    explicit parameters instead of relying on module-scoped state.

    Hard requirements:
      - Windows + PowerShell 7
      - IIS installed (uses Microsoft.Web.Administration directly,
        no WebAdministration PowerShell module needed)
      - SqlServer module (Invoke-Sqlcmd)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Environment / IIS .NET assembly loading
# ---------------------------------------------------------------------------

function Assert-StandaloneEnvironment {
    if (-not $IsWindows) {
        throw "Standalone Sitefinity scripts require Windows."
    }

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "Standalone Sitefinity scripts require PowerShell 7 or later. Current: $($PSVersionTable.PSVersion)"
    }

    if (-not ('Microsoft.Web.Administration.ServerManager' -as [type])) {
        $dll = Join-Path $env:WINDIR 'System32\inetsrv\Microsoft.Web.Administration.dll'
        if (-not (Test-Path $dll)) {
            throw "Microsoft.Web.Administration.dll not found at '$dll'. Install IIS (Windows feature 'Web-Server') and try again."
        }
        Add-Type -Path $dll
    }

    # ServerManager reads applicationHost.config directly; that requires admin.
    # Without elevation it silently returns an empty/phantom site list.
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [System.Security.Principal.WindowsPrincipal]::new($id)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run as Administrator (Microsoft.Web.Administration requires elevation to read IIS configuration)."
    }

    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        throw "Required module 'SqlServer' is not installed. Run: Install-Module SqlServer -Scope CurrentUser"
    }
    Import-Module SqlServer -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
}

function _newServerManager {
    return [Microsoft.Web.Administration.ServerManager]::new()
}

# ---------------------------------------------------------------------------
# Project resolution from a project-root path
# ---------------------------------------------------------------------------

function Resolve-SfProjectInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot
    )

    if (-not (Test-Path $ProjectRoot)) {
        throw "Project root path not found: '$ProjectRoot'."
    }

    $ProjectRoot = (Resolve-Path $ProjectRoot).Path

    $webAppPath = $null
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

    $WebsiteName = Find-IisSiteByPhysicalPath -PhysicalPath $webAppPath
    if (-not $WebsiteName) {
        $sm = _newServerManager
        try {
            $known = @($sm.Sites | ForEach-Object {
                $rootApp = $_.Applications | Where-Object { $_.Path -eq '/' } | Select-Object -First 1
                $vdir = $null
                if ($rootApp) { $vdir = $rootApp.VirtualDirectories | Where-Object { $_.Path -eq '/' } | Select-Object -First 1 }
                $p = if ($vdir) { $vdir.PhysicalPath } else { '<unknown>' }
                "$($_.Name) -> $p"
            })
        }
        finally { $sm.Dispose() }
        $detail = if ($known) { "`nKnown sites:`n  " + ($known -join "`n  ") } else { '' }
        throw "Could not determine IIS website for web app path '$webAppPath'.$detail"
    }

    return [pscustomobject]@{
        ProjectRoot = $ProjectRoot
        WebAppPath  = $webAppPath
        WebsiteName = $WebsiteName
        DbName      = Resolve-SfProjectDbName -WebAppPath $webAppPath
    }
}

function Resolve-SfProjectDbName {
    param([Parameter(Mandatory)][string]$WebAppPath)

    # Resolve the DB name from the project's DataConfig.config (Sitefinity
    # connection string). Returns empty when there is no data config yet
    # (e.g. project has been uninitialized).
    $name = Get-SfDbNameFromDataConfig -WebAppPath $WebAppPath
    if (-not $name) { return '' }
    return $name
}

function Find-IisSiteByPhysicalPath {
    param(
        [Parameter(Mandatory)][string]$PhysicalPath
    )

    $target = _normalizePath $PhysicalPath

    $sm = _newServerManager
    try {
        foreach ($site in $sm.Sites) {
            foreach ($app in $site.Applications) {
                foreach ($vdir in $app.VirtualDirectories) {
                    if ($vdir.Path -eq '/' -and (_normalizePath $vdir.PhysicalPath) -eq $target) {
                        return $site.Name
                    }
                }
            }
        }
    }
    finally { $sm.Dispose() }

    return $null
}

function _normalizePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }

    # IIS may store paths with env vars (e.g. %SystemDrive%\...).
    $expanded = [System.Environment]::ExpandEnvironmentVariables($Path)

    try {
        $full = [System.IO.Path]::GetFullPath($expanded)
    }
    catch {
        $full = $expanded
    }

    return $full.TrimEnd('\', '/').ToLowerInvariant()
}

# ---------------------------------------------------------------------------
# IIS helpers
# ---------------------------------------------------------------------------

function Test-IisSiteStarted {
    param([Parameter(Mandatory)][string]$WebsiteName)
    $sm = _newServerManager
    try {
        $site = $sm.Sites[$WebsiteName]
        if (-not $site) { throw "IIS website '$WebsiteName' not found." }
        return $site.State -eq [Microsoft.Web.Administration.ObjectState]::Started
    }
    finally { $sm.Dispose() }
}

function Start-IisSite {
    param([Parameter(Mandatory)][string]$WebsiteName)
    $sm = _newServerManager
    try {
        $site = $sm.Sites[$WebsiteName]
        if (-not $site) { throw "IIS website '$WebsiteName' not found." }
        $site.Start() | Out-Null
    }
    finally { $sm.Dispose() }
}

function Reset-IisAppPoolForSite {
    param([Parameter(Mandatory)][string]$WebsiteName)

    $sm = _newServerManager
    try {
        $site = $sm.Sites[$WebsiteName]
        if (-not $site) { throw "IIS website '$WebsiteName' not found." }

        $rootApp = $site.Applications | Where-Object { $_.Path -eq '/' } | Select-Object -First 1
        $appPool = if ($rootApp) { $rootApp.ApplicationPoolName } else { $null }
        if ([string]::IsNullOrEmpty($appPool)) {
            throw "No application pool set for website '$WebsiteName'."
        }

        $pool = $sm.ApplicationPools[$appPool]
        if (-not $pool) { throw "Application pool '$appPool' not found." }
        $pool.Recycle() | Out-Null
    }
    finally { $sm.Dispose() }
}

function Get-IisSiteBindings {
    param([Parameter(Mandatory)][string]$WebsiteName)

    $sm = _newServerManager
    try {
        $site = $sm.Sites[$WebsiteName]
        if (-not $site) { throw "IIS website '$WebsiteName' not found." }
        return @($site.Bindings | ForEach-Object {
            $info = [string]$_.BindingInformation
            $parts = $info.Split(':')
            [pscustomobject]@{
                Protocol = [string]$_.Protocol
                Port     = if ($parts.Count -ge 2) { $parts[1] } else { '' }
                Domain   = if ($parts.Count -ge 3) { $parts[2] } else { '' }
            }
        })
    }
    finally { $sm.Dispose() }
}

function Get-IisSubAppName {
    param([Parameter(Mandatory)][string]$WebsiteName)

    $sm = _newServerManager
    try {
        $site = $sm.Sites[$WebsiteName]
        if (-not $site) { return $null }
        foreach ($app in $site.Applications) {
            if ($app.Path -and $app.Path -ne '/') {
                return $app.Path.TrimStart('/')
            }
        }
        return $null
    }
    finally { $sm.Dispose() }
    return $null
}

function Get-IisSiteUrl {
    param(
        [Parameter(Mandatory)][string]$WebsiteName
    )

    $bindings = Get-IisSiteBindings -WebsiteName $WebsiteName
    if (-not $bindings -or $bindings.Count -eq 0) {
        throw "Website '$WebsiteName' has no bindings."
    }

    $binding = $bindings | Select-Object -Last 1
    $hostname = if ($binding.Domain) { $binding.Domain } else { 'localhost' }
    $url = "$($binding.Protocol)://${hostname}:$($binding.Port)"

    $subApp = Get-IisSubAppName -WebsiteName $WebsiteName
    if ($subApp) {
        $url = "$url/$subApp"
    }

    return $url
}

# ---------------------------------------------------------------------------
# DataConfig.config / StartupConfig.config
# ---------------------------------------------------------------------------

function Get-SfDbNameFromDataConfig {
    param([Parameter(Mandatory)][string]$WebAppPath)

    $dataConfigPath = Join-Path $WebAppPath 'App_Data\Sitefinity\Configuration\DataConfig.config'
    if (-not (Test-Path $dataConfigPath)) {
        return $null
    }

    [xml]$data = Get-Content $dataConfigPath -Raw
    $sfConStrEl = $data.dataConfig.connectionStrings.add | Where-Object { $_.name -eq 'Sitefinity' }
    if (-not $sfConStrEl) {
        return $null
    }

    if ($sfConStrEl.connectionString -match "initial catalog='{0,1}(?<dbName>.*?)'{0,1}(;|$)") {
        return $matches['dbName']
    }

    return $null
}

function New-SfStartupConfig {
    param(
        [Parameter(Mandatory)][string]$WebAppPath,
        [Parameter(Mandatory)][string]$DbName,
        [Parameter(Mandatory)][string]$SqlServerInstance,
        [Parameter(Mandatory)][string]$SqlUser,
        [Parameter(Mandatory)][string]$SqlPassword,
        [Parameter(Mandatory)][string]$SitefinityUser,
        [Parameter(Mandatory)][string]$SitefinityPassword
    )

    if ([string]::IsNullOrWhiteSpace($DbName)) {
        throw "Cannot create StartupConfig with empty database name."
    }

    if (Test-SqlDbExists -DbName $DbName -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword) {
        throw "Database '$DbName' already exists; refusing to overwrite via StartupConfig."
    }

    $configDir = Join-Path $WebAppPath 'App_Data\Sitefinity\Configuration'
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir | Out-Null
    }

    $configPath = Join-Path $configDir 'StartupConfig.config'
    if (Test-Path $configPath) {
        Remove-Item $configPath -Force
    }

    $username = $SitefinityUser.Split('@')[0]

    $writer = New-Object System.Xml.XmlTextWriter($configPath, $null)
    try {
        $writer.WriteStartDocument()
        $writer.WriteStartElement('startupConfig')
        $writer.WriteAttributeString('username', $SitefinityUser)
        $writer.WriteAttributeString('password', $SitefinityPassword)
        $writer.WriteAttributeString('enabled', 'True')
        $writer.WriteAttributeString('initialized', 'False')
        $writer.WriteAttributeString('email', $SitefinityUser)
        $writer.WriteAttributeString('firstName', $username)
        $writer.WriteAttributeString('lastName', $username)
        $writer.WriteAttributeString('dbName', $DbName)
        $writer.WriteAttributeString('dbType', 'SqlServer')
        $writer.WriteAttributeString('sqlInstance', $SqlServerInstance)
        $writer.WriteAttributeString('sqlAuthUserName', $SqlUser)
        $writer.WriteAttributeString('sqlAuthUserPassword', $SqlPassword)
        $writer.WriteEndElement()
        $writer.Flush()
    }
    finally {
        $writer.Close() | Out-Null
    }
}

function Reset-SitefinityAppDataFolder {
    param([Parameter(Mandatory)][string]$WebAppPath)

    $sfFolder = Join-Path $WebAppPath 'App_Data\Sitefinity'
    if (-not (Test-Path $sfFolder)) {
        return
    }

    $targets = Get-ChildItem $sfFolder -Directory |
        Where-Object { $_.Name -in @('Configuration', 'Temp', 'Logs') }

    $errors = @()
    foreach ($d in $targets) {
        try {
            Remove-Item $d.FullName -Recurse -Force -ErrorAction Stop
        }
        catch {
            $errors += $_
        }
    }

    if ($errors) {
        Write-Warning "Errors while resetting Sitefinity App_Data folder: $($errors -join '; ')"
    }
}

# ---------------------------------------------------------------------------
# SQL helpers
# ---------------------------------------------------------------------------

function Invoke-SfSqlcmd {
    param(
        [Parameter(Mandatory)][string]$SqlServerInstance,
        [Parameter(Mandatory)][string]$SqlUser,
        [Parameter(Mandatory)][string]$SqlPassword,
        [Parameter(Mandatory)][string]$Query
    )

    return Invoke-Sqlcmd `
        -ServerInstance $SqlServerInstance `
        -Username       $SqlUser `
        -Password       $SqlPassword `
        -Query          $Query `
        -TrustServerCertificate
}

function Test-SqlDbExists {
    param(
        [Parameter(Mandatory)][string]$DbName,
        [Parameter(Mandatory)][string]$SqlServerInstance,
        [Parameter(Mandatory)][string]$SqlUser,
        [Parameter(Mandatory)][string]$SqlPassword
    )
    $rows = @(Invoke-SfSqlcmd -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword `
        -Query "SELECT name FROM sys.databases WHERE name = '$DbName'")
    return $rows.Count -gt 0
}

function Remove-SqlDatabaseIfExists {
    param(
        [Parameter(Mandatory)][string]$DbName,
        [Parameter(Mandatory)][string]$SqlServerInstance,
        [Parameter(Mandatory)][string]$SqlUser,
        [Parameter(Mandatory)][string]$SqlPassword
    )

    if ([string]::IsNullOrWhiteSpace($DbName)) {
        Write-Warning "Skipping SQL database delete: empty name."
        return
    }

    $rows = @(Invoke-SfSqlcmd -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword `
        -Query "SELECT name FROM sys.databases WHERE name = '$DbName'")
    foreach ($row in $rows) {
        $name = $row.name
        Invoke-SfSqlcmd -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword -Query @"
ALTER DATABASE [$name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE [$name];
"@ | Out-Null
    }
}

# ---------------------------------------------------------------------------
# HTTP polling
# ---------------------------------------------------------------------------

function Invoke-NonTerminatingRequest {
    param([Parameter(Mandatory)][string]$Url)

    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 120 -UseBasicParsing
        return $response.StatusCode
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode
        if ($statusCode) {
            return $statusCode.ToString()
        }
        return $null
    }
}

# ---------------------------------------------------------------------------
# High-level workflows
# ---------------------------------------------------------------------------

function Invoke-SfAppEnsureRunning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Project,
        [Parameter(Mandatory)][string]$SqlServerInstance,
        [Parameter(Mandatory)][string]$SqlUser,
        [Parameter(Mandatory)][string]$SqlPassword,
        [int]$TotalWaitSeconds = 180
    )

    if (-not (Test-IisSiteStarted -WebsiteName $Project.WebsiteName)) {
        Start-IisSite -WebsiteName $Project.WebsiteName
        if (-not (Test-IisSiteStarted -WebsiteName $Project.WebsiteName)) {
            throw "Website '$($Project.WebsiteName)' is stopped in IIS. Duplicate port?"
        }
    }

    $dbName = Get-SfDbNameFromDataConfig -WebAppPath $Project.WebAppPath
    if ($dbName) {
        if (-not (Test-SqlDbExists -DbName $dbName -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword)) {
            throw "Project database '$dbName' not found in database server."
        }
    }
    else {
        $startupConfigPath = Join-Path $Project.WebAppPath 'App_Data\Sitefinity\Configuration\StartupConfig.config'
        if (-not (Test-Path $startupConfigPath)) {
            throw "No DataConfig.config found and no StartupConfig.config found."
        }
    }

    $url = Get-IisSiteUrl -WebsiteName $Project.WebsiteName
    if (-not $url) { throw "Could not construct site URL." }

    Write-Information "Starting Sitefinity at $url ..." -InformationAction Continue
    $previousErrAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $response = Invoke-NonTerminatingRequest -Url $url
        if ($response -and $response -ne 200 -and $response -ne 503) {
            throw "Could not make initial connection to Sitefinity. StatusCode: $response"
        }

        $statusUrl = "$url/appstatus"
        Write-Information "Polling Sitefinity status at '$statusUrl'" -InformationAction Continue
        $elapsed = [System.Diagnostics.Stopwatch]::StartNew()

        while ($true) {
            $response = Invoke-NonTerminatingRequest -Url $statusUrl
            if ($elapsed.Elapsed.TotalSeconds -gt $TotalWaitSeconds) {
                throw "Sitefinity did NOT start within $TotalWaitSeconds seconds."
            }

            if ($response -eq 200) {
                Write-Progress -Activity 'Waiting for Sitefinity to start' -PercentComplete (($elapsed.Elapsed.TotalSeconds / $TotalWaitSeconds) * 100)
                Start-Sleep -Seconds 5
                continue
            }

            if ($response -eq 404 -or $response -eq 'NotFound') {
                $response = Invoke-NonTerminatingRequest -Url $url
                if ($response -eq 200) {
                    $elapsed.Stop()
                    Write-Information "Sitefinity has started after $([int]$elapsed.Elapsed.TotalSeconds) second(s)." -InformationAction Continue
                    return
                }

                $elapsed.Stop()
                throw "Sitefinity initialization failed (base URL returned: $response)."
            }

            $elapsed.Stop()
            throw "Sitefinity failed to start - StatusCode: $response"
        }
    }
    finally {
        $ErrorActionPreference = $previousErrAction
    }
}

function Invoke-SfAppUninitialize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Project,
        [Parameter(Mandatory)][string]$SqlServerInstance,
        [Parameter(Mandatory)][string]$SqlUser,
        [Parameter(Mandatory)][string]$SqlPassword
    )

    try {
        Reset-IisAppPoolForSite -WebsiteName $Project.WebsiteName

        $dbName = Get-SfDbNameFromDataConfig -WebAppPath $Project.WebAppPath
        if ($dbName) {
            Remove-SqlDatabaseIfExists -DbName $dbName -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword
        }

        Reset-SitefinityAppDataFolder -WebAppPath $Project.WebAppPath
    }
    catch {
        Write-Warning "Errors occurred while uninitializing app: $_"
    }
}

function Invoke-SfAppInitialize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Project,
        [Parameter(Mandatory)][string]$SqlServerInstance,
        [Parameter(Mandatory)][string]$SqlUser,
        [Parameter(Mandatory)][string]$SqlPassword,
        [Parameter(Mandatory)][string]$SitefinityUser,
        [Parameter(Mandatory)][string]$SitefinityPassword,
        [Parameter(Mandatory)][string]$DbName,
        [int]$TotalWaitSeconds = 180,
        [switch]$SkipEnsureRunning
    )

    if (Get-SfDbNameFromDataConfig -WebAppPath $Project.WebAppPath) {
        throw "Already initialized. Uninitialize first."
    }

    Start-Sleep -Seconds 1

    Remove-SqlDatabaseIfExists -DbName $DbName -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword
    New-SfStartupConfig -WebAppPath $Project.WebAppPath -DbName $DbName `
        -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword `
        -SitefinityUser $SitefinityUser -SitefinityPassword $SitefinityPassword

    if (-not $SkipEnsureRunning) {
        Invoke-SfAppEnsureRunning -Project $Project `
            -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword `
            -TotalWaitSeconds $TotalWaitSeconds
    }
}

function Invoke-SfAppReinitialize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Project,
        [Parameter(Mandatory)][string]$SqlServerInstance,
        [Parameter(Mandatory)][string]$SqlUser,
        [Parameter(Mandatory)][string]$SqlPassword,
        [Parameter(Mandatory)][string]$SitefinityUser,
        [Parameter(Mandatory)][string]$SitefinityPassword,
        [Parameter(Mandatory)][string]$DbName,
        [int]$TotalWaitSeconds = 180,
        [switch]$SkipEnsureRunning
    )

    Invoke-SfAppUninitialize -Project $Project `
        -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword

    Invoke-SfAppInitialize -Project $Project `
        -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword `
        -SitefinityUser $SitefinityUser -SitefinityPassword $SitefinityPassword `
        -DbName $DbName -TotalWaitSeconds $TotalWaitSeconds -SkipEnsureRunning:$SkipEnsureRunning
}
