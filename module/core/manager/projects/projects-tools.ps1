function sf-clean-allProjectsLeftovers {
    $projectsDir = $global:projectsDirectory
    $idsInUse = _sfData-get-allProjects | ForEach-Object { $_.id }
    
    function shouldClean {
        param (
            $id
        )
        
        if (-not $id -match "$Global:idPrefix\d+") {
            return $false
        }
        
        if (-not $idsInUse.Contains($id)) {
            return $true
        }
    
        return $false
    }

    $errors = ''
    function add-error ($text) {
        $errors = "$errors$text`n"
    }

    try {
        Write-Host "Sites cleanup"
        Import-Module WebAdministration
        $sites = Get-Item "IIS:\Sites" 
        $names = $sites.Children.Keys | Where-Object { shouldClean $_ }
        
        foreach ($site in $names) {
            Remove-Item "IIS:\Sites\$($site)" -Force -Recurse
        }
    }
    catch {
        add-error "Sites were not cleaned up: $_"
    }

    try {
        Write-Host "App pool cleanup"
        Import-Module WebAdministration
        $pools = Get-Item "IIS:\AppPools" 
        $names = $pools.Children.Keys | Where-Object { shouldClean $_ }
        foreach ($poolName in $names) {
            Remove-Item "IIS:\AppPools\$($poolName)" -Force -Recurse
        }
    }
    catch {
        add-error "Application pools were not cleaned up: $_"
    }

    try {
        Write-Host "SQL logins cleanup"
        $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList '.'
        $allLogins = $sqlServer.Logins | Where-Object { shouldClean $_.Name }
        $allLogins | ForEach-Object {$_.Drop()}
    }
    catch {
        add-error "SQL logins were not cleaned up: $_"
    }

    try {
        Write-Host "Domain mapping cleanup"
        Show-Domains | Where-Object { shouldClean $_ } | ForEach-Object { $_.Split(' ')[0] } | ForEach-Object { Remove-Domain $_ }
    }
    catch {
        add-error "Domains were not cleaned up: $_"
    }

    try {
        Write-Host "TFS cleanup"
        $wss = tfs-get-workspaces 
        $wss | Where-Object { shouldClean $_ } | ForEach-Object { tfs-delete-workspace $_ }
    }
    catch {
        add-error "Tfs workspaces were not cleaned up: $_"
    }

    try {
        Write-Host "DBs cleanup"
        $dbs = sql-get-dbs 
        $dbs | Where-Object { $_.name.StartsWith("$Global:idPrefix") -and (shouldClean $_.name) } | ForEach-Object { sql-delete-database $_.name }
    }
    catch {
        add-error "Databases were not cleaned up: $_"
    }

    try {
        Set-Location -Path $PSHOME
        sleep.exe 5
        Write-Host "Projects directory cleanup"
        unlock-allFiles $projectsDir
        Get-ChildItem $projectsDir | Where-Object { shouldClean $_.Name } | % { Remove-Item $_.FullName -Force -Recurse }
    }
    catch {
        add-error "Test sitefinities were not cleaned up: $_"
    }

    if ($errors) {
        throw $errors
    }
}

function sf-reset-project {
    param(
        [SfProject]
        $sf
    )

    if (-not $sf) {
        $sf = _get-selectedProject
    }

    if ($sf.lastGetLatest -and [System.DateTime]::Parse($sf.lastGetLatest) -lt [System.DateTime]::Today) {
        $shouldReset = $false
        if (sf-get-hasPendingChanges) {
            sf-undo-pendingChanges
            $shouldReset = $true
        }

        $getLatestOutput = sf-get-latestChanges -overwrite
        if (-not ($getLatestOutput.Contains('All files are up to date.'))) {
            $shouldReset = $true
        }

        if ($shouldReset) {
            sf-clean-solution -cleanPackages $true
            sf-reset-app -start -build -precompile
            sf-new-appState -stateName initial
        }
    }
}