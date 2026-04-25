sf-app-ensureRunning
sf-app-reinitialize

## Standalone (no module needed, pwsh 7)

Windows + PowerShell 7 (run elevated). IIS (Microsoft.Web.Administration) + `SqlServer` module.

- [scripts/standalone/Sf-App-EnsureRunning.ps1](scripts/standalone/Sf-App-EnsureRunning.ps1) – standalone equivalent of `sf-app-ensureRunning`
- [scripts/standalone/Sf-App-Reinitialize.ps1](scripts/standalone/Sf-App-Reinitialize.ps1) – standalone equivalent of `sf-app-reinitialize`
- [scripts/standalone/Sf-Site-New.ps1](scripts/standalone/Sf-Site-New.ps1) – standalone equivalent of `sf-iis-site-new` (creates IIS site + app pool for a project)
- [scripts/standalone/Sf-Project-Info.ps1](scripts/standalone/Sf-Project-Info.ps1) – returns `{ProjectRoot, WebAppPath, WebsiteName, DbName}` for a given path

```powershell
pwsh -File .\scripts\standalone\Sf-App-EnsureRunning.ps1 `
    -ProjectRoot 'C:\sites\my-sf' `
    -SqlServerInstance '.' -SqlUser 'sa' -SqlPassword 'pw'

pwsh -File .\scripts\standalone\Sf-App-Reinitialize.ps1 `
    -ProjectRoot 'C:\sites\my-sf' `
    -SqlServerInstance '.' -SqlUser 'sa' -SqlPassword 'pw' `
    -SitefinityUser 'admin@test.test' -SitefinityPassword 'pw'
```

`-ProjectRoot` may be the web app folder itself (containing `web.config`) or a parent solution folder containing `SitefinityWebApp`. The IIS website and the new database name are auto-resolved from the project (database name = project folder name). `-SkipEnsureRunning` skips the readiness wait after reinit.