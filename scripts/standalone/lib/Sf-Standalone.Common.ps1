<#
.SYNOPSIS
    Shared helpers for the standalone Sitefinity app scripts.

.DESCRIPTION
    Behavior-equivalent extraction of the parts of Sf-PoSh needed by
    sf-app-ensureRunning and sf-app-reinitialize, refactored to take
    explicit parameters instead of relying on module-scoped state.

    Hard requirements:
      - Windows + PowerShell 7
      - WebAdministration module (IIS)
      - SqlServer module (Invoke-Sqlcmd)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Environment / module loading
# ---------------------------------------------------------------------------

function Assert-StandaloneEnvironment {
    if (-not $IsWindows) {
        throw "Standalone Sitefinity scripts require Windows."
    }

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "Standalone Sitefinity scripts require PowerShell 7 or later. Current: $($PSVersionTable.PSVersion)"
    }

    # WebAdministration ships only with Windows PowerShell 5.1. In pwsh 7 we
    # import it through the Windows PowerShell compatibility session, which
    # proxies the cmdlets (Get-Website, Get-WebBinding, IIS:\ drive, etc).
    if (-not (Get-Module -Name WebAdministration)) {
        # WebAdministration lives under Windows PowerShell, not under pwsh 7,
        # so Get-Module -ListAvailable won't see it. Just attempt the compat
        # import directly. The non-terminating "elevated status" error emitted
        # on first load when not admin is harmless (the proxy still loads).
        Import-Module WebAdministration -UseWindowsPowerShell -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null

        if (-not (Get-Module -Name WebAdministration)) {
            throw "Failed to load WebAdministration via Windows PowerShell compatibility. Ensure IIS Management Scripts and Tools are installed (Windows feature 'Web-Scripting-Tools') and run pwsh as Administrator."
        }
    }

    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        throw "Required module 'SqlServer' is not installed. Run: Install-Module SqlServer -Scope CurrentUser"
    }
    Import-Module SqlServer -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
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
        $known = @(Get-Website | ForEach-Object { "$($_.Name) -> $($_.physicalPath)" })
        $detail = if ($known) { "`nKnown sites:`n  " + ($known -join "`n  ") } else { '' }
        throw "Could not determine IIS website for web app path '$webAppPath'.$detail"
    }

    if (-not (Get-Website -Name $WebsiteName -ErrorAction SilentlyContinue)) {
        throw "IIS website '$WebsiteName' does not exist."
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

    foreach ($site in @(Get-Website)) {
        if ((_normalizePath $site.physicalPath) -eq $target) {
            return $site.Name
        }
    }

    foreach ($app in @(Get-WebApplication)) {
        if ((_normalizePath $app.PhysicalPath) -eq $target) {
            # Get-WebApplication returns objects with a GetParentElement method
            # only when used via the IIS:\ provider. With proxied cmdlets the
            # site name is exposed directly on the object.
            if ($app.PSObject.Properties.Match('GetSite').Count) {
                return $app.GetSite().Name
            }
            if ($app.PSObject.Properties.Match('SiteName').Count) {
                return [string]$app.SiteName
            }
        }
    }

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
    return (Get-WebsiteState -Name $WebsiteName).Value -eq 'Started'
}

function Reset-IisAppPoolForSite {
    param([Parameter(Mandatory)][string]$WebsiteName)

    $appPool = (Get-Website -Name $WebsiteName).applicationPool
    if ([string]::IsNullOrEmpty($appPool)) {
        throw "No application pool set for website '$WebsiteName'."
    }

    Restart-WebAppPool -Name $appPool
}

function Get-IisSiteBindings {
    param([Parameter(Mandatory)][string]$WebsiteName)

    $bindings = @(Get-WebBinding -Name $WebsiteName)
    return $bindings | ForEach-Object {
        $info = $_.bindingInformation
        [pscustomobject]@{
            Protocol = $_.protocol
            Port     = $info.Split(':')[1]
            Domain   = $info.Split(':')[2]
        }
    }
}

function Get-IisSubAppName {
    param([Parameter(Mandatory)][string]$WebsiteName)

    $apps = @(Get-WebApplication -Site $WebsiteName)
    foreach ($app in $apps) {
        if ($app.path -and $app.path -ne '/') {
            return $app.path.TrimStart('/')
        }
    }
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
        Start-Website -Name $Project.WebsiteName
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
        [string]$DbName,
        [int]$TotalWaitSeconds = 180,
        [switch]$SkipEnsureRunning
    )

    Invoke-SfAppUninitialize -Project $Project `
        -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword

    if (-not $DbName) {
        # Default new DB name to the project root folder name (parity with sf-app-initialize using $p.id).
        $DbName = Split-Path $Project.ProjectRoot -Leaf
    }

    Invoke-SfAppInitialize -Project $Project `
        -SqlServerInstance $SqlServerInstance -SqlUser $SqlUser -SqlPassword $SqlPassword `
        -SitefinityUser $SitefinityUser -SitefinityPassword $SitefinityPassword `
        -DbName $DbName -TotalWaitSeconds $TotalWaitSeconds -SkipEnsureRunning:$SkipEnsureRunning
}
