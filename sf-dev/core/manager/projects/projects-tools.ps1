function sf-clean-allProjectsLeftovers {
    $projectsDir = $Script:projectsDirectory
    $idsInUse = _sfData-get-allProjects | ForEach-Object { $_.id }
    
    function shouldClean {
        param (
            $id
        )

        if (-not ($id -match "$Script:idPrefix\d+")) {
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
        Write-Information "Sites cleanup"
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
        Write-Information "App pool cleanup"
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
        Write-Information "TFS cleanup"
        $wss = tfs-get-workspaces $Script:tfsServerName
        $wss | Where-Object { shouldClean $_ } | ForEach-Object { tfs-delete-workspace $_ $Script:tfsServerName }
    }
    catch {
        add-error "Tfs workspaces were not cleaned up: $_"
    }

    try {
        Write-Information "DBs cleanup"
        [SqlClient]$sql = _get-sqlClient
        $dbs = $sql.GetDbs()
        $dbs | Where-Object { $_.name.StartsWith("$Script:idPrefix") -and (shouldClean $_.name) } | ForEach-Object {
            $sql.Delete($_.name)
        }
    }
    catch {
        add-error "Databases were not cleaned up: $_"
    }

    try {
        Set-Location -Path $PSHOME
        sleep.exe 5
        Write-Information "Projects directory cleanup"
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
        $project
    )

    if (-not $project) {
        $project = _get-selectedProject
    }

    if ($project.lastGetLatest -and [System.DateTime]::Parse($project.lastGetLatest) -lt [System.DateTime]::Today) {
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