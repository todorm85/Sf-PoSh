sf-app-ensureRunning
sf-app-reinitialize

## Standalone (no module needed, pwsh 7)

Windows + PowerShell 7 (run elevated). IIS (Microsoft.Web.Administration) + `SqlServer` module.

- [scripts/standalone/Sfs-EnsureRunning-SitefinityApp.ps1](scripts/standalone/Sfs-EnsureRunning-SitefinityApp.ps1) – starts the IIS site for a Sitefinity project and waits for `/appstatus` to report ready
- [scripts/standalone/Sfs-Reset-SitefinityApp.ps1](scripts/standalone/Sfs-Reset-SitefinityApp.ps1) – uninitializes a Sitefinity app and re-initializes it against a fresh `-DbName`. `-DeleteOldDatabase` also drops the DB previously recorded in `DataConfig.config`
- [scripts/standalone/Sfs-Create-SitefinityAppIisSite.ps1](scripts/standalone/Sfs-Create-SitefinityAppIisSite.ps1) – creates a dedicated IIS website + application pool for a Sitefinity project on disk
- [scripts/standalone/Sfs-Get-SitefinityAppInfo.ps1](scripts/standalone/Sfs-Get-SitefinityAppInfo.ps1) – returns project + site info (paths, DB name, app pool, bindings, URLs) for a given path
- [scripts/standalone/Sfs-Build-SitefinityApp.ps1](scripts/standalone/Sfs-Build-SitefinityApp.ps1) – builds the Sitefinity solution (or just `SitefinityWebApp.csproj`) with optional `-Restore`, `-Clean`, `-CleanPackages`, `-RetryCount`. MSBuild is auto-discovered via vswhere/PATH; nuget.exe is auto-discovered or downloaded.

```powershell
pwsh -File .\scripts\standalone\Sfs-EnsureRunning-SitefinityApp.ps1 `
    -ProjectRoot 'C:\sites\my-sf'

pwsh -File .\scripts\standalone\Sfs-Reset-SitefinityApp.ps1 `
    -ProjectRoot 'C:\sites\my-sf' `
    -SqlServerInstance '.' -SqlUser 'sa' -SqlPassword 'pw' `
    -SitefinityUser 'admin@test.test' -SitefinityPassword 'pw' `
    -DbName 'my-sf'
```

`-ProjectRoot` may be the web app folder itself (containing `web.config`) or a parent solution folder containing `SitefinityWebApp`. It defaults to `$env:SF_PROJECT_ROOT`; if neither the param nor the env var is supplied the script throws. The IIS website is auto-resolved from the project. `-SkipEnsureRunning` skips the readiness wait after reset.

SQL connection params (`-SqlServerInstance`, `-SqlUser`, `-SqlPassword`) default to `$env:SF_SQL_SERVER`, `$env:SF_SQL_USER`, `$env:SF_SQL_PASSWORD` respectively, so the MCP server (or your shell) can supply them once and callers can omit them.