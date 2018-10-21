function clean-testAll () {
    . ".\load-module.ps1"

    iisreset.exe

    stop-allMsbuild
    
    $baseTestId = $script:idPrefix

    try {
        Write-Host "Sites cleanup"
        $sites = Get-Item "iis:\Sites" 
        $names = $sites.Children.Keys | Where-Object { $_.StartsWith($baseTestId) }
        
        foreach ($site in $names) {
            Remove-Item "iis:\Sites\$($site)" -Force -Recurse
        }
    }
    catch {
        Write-Warning "Sites were not cleaned up: $_"
    }

    try {
        Write-Host "App pool cleanup"
        $pools = Get-Item "iis:\AppPools" 
        $names = $pools.Children.Keys | Where-Object { $_.StartsWith($baseTestId) }
        foreach ($poolName in $names) {
            Remove-Item "iis:\AppPools\$($poolName)" -Force -Recurse
        }
    }
    catch {
        Write-Warning "Application pools were not cleaned up: $_"
    }

    try {
        Write-Host "SQL logins cleanup"
        _sql-load-module
        $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
        $allLogins = $sqlServer.Logins | Where-Object {$_.Name.Contains($baseTestId)}
        $allLogins | ForEach-Object {$_.Drop()}
    }
    catch {
        Write-Warning "SQL logins were not cleaned up: $_"
    }

    try {
        Write-Host "Domain mapping cleanup"
        Show-Domains | Where-Object {$_.Contains($baseTestId)} | ForEach-Object {$_.Split(' ')[0]} | ForEach-Object {Remove-Domain $_}
    }
    catch {
        Write-Warning "SQL logins were not cleaned up: $_"
    }

    try {
        Write-Host "TFS cleanup"
        $wss = tfs-get-workspaces 
        $wss | Where-Object {$_.StartsWith($baseTestId) } | ForEach-Object { tfs-delete-workspace $_ }
    }
    catch {
        Write-Warning "Tfs workspaces were not cleaned up: $_"
    }

    try {
        Write-Host "DBs cleanup"
        $dbs = sql-get-dbs 
        $dbs | Where-Object {$_.name.StartsWith($baseTestId) } | ForEach-Object { sql-delete-database $_.name }
    }
    catch {
        Write-Warning "Databases were not cleaned up: $_"
    }

    # clean-testDb

    try {
        Set-Location -Path $PSHOME
        sleep.exe 5
        Write-Host "Projects directory cleanup"
        Remove-Item $Script:projectsDirectory -Force -Recurse
    }
    catch {
        Write-Warning "Test sitefinities were not cleaned up: $_"
    }

    Set-Location "$PSScriptRoot\..\"
}

function stop-allMsbuild {
    try {
        $processes = Get-Process msbuild -ErrorAction Stop | Stop-Process -ErrorAction Stop
    }
    catch {
        Write-Warning "MSBUILD stop: $_"
    }
}
