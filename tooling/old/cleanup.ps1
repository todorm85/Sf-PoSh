Import-Module dev -Force

function sf-project-tools-clearAllProjectsLeftovers {
    $projectsDir = $GLOBAL:sf.Config.projectsDirectory
    $idsInUse = sf-project-get -all | ForEach-Object { $_.id }

    function _shouldClean {
        param (
            $id
        )

        if (-not ($id -match "$($GLOBAL:sf.Config.idPrefix)\d+")) {
            return $false
        }

        if (-not $idsInUse.Contains($id)) {
            return $true
        }

        return $false
    }

    $errors = ''
    function _addError ($text) {
        $errors = "$errors$text`n"
    }

    try {
        Write-Information "Sites cleanup"
        Import-Module WebAdministration
        $sites = Get-Item "IIS:\Sites"
        $names = $sites.Children.Keys | Where-Object { _shouldClean $_ }

        foreach ($site in $names) {
            Remove-Item "IIS:\Sites\$($site)" -Force -Recurse
        }
    }
    catch {
        _addError "Sites were not cleaned up: $_"
    }

    try {
        Write-Information "App pool cleanup"
        Import-Module WebAdministration
        $pools = Get-Item "IIS:\AppPools"
        $names = $pools.Children.Keys | Where-Object { _shouldClean $_ }
        foreach ($poolName in $names) {
            Remove-Item "IIS:\AppPools\$($poolName)" -Force -Recurse
        }
    }
    catch {
        _addError "Application pools were not cleaned up: $_"
    }

    try {
        Write-Information "TFS cleanup"
        $wss = tfs-get-workspaces $GLOBAL:sf.Config.tfsServerName
        $wss | Where-Object { _shouldClean $_ } | ForEach-Object { tfs-delete-workspace $_ $GLOBAL:sf.Config.tfsServerName }
    }
    catch {
        _addError "Tfs workspaces were not cleaned up: $_"
    }

    try {
        Write-Information "DBs cleanup"

        $dbs = sql-get-dbs
        $dbs | Where-Object { $_.name.StartsWith("$($GLOBAL:sf.Config.idPrefix)") -and (_shouldClean $_.name) } | ForEach-Object {
            sql-delete-database -dbName $_.name
        }
    }
    catch {
        _addError "Databases were not cleaned up: $_"
    }

    try {
        Set-Location -Path $PSHOME
        sleep.exe 5
        Write-Information "Projects directory cleanup"
        unlock-allFiles $projectsDir
        Get-ChildItem $projectsDir | Where-Object { _shouldClean $_.Name } | ForEach-Object { Remove-Item $_.FullName -Force -Recurse }
    }
    catch {
        _addError "Test sitefinities were not cleaned up: $_"
    }

    if ($errors) {
        throw $errors
    }
}

sf-project-tools-clearAllProjectsLeftovers
