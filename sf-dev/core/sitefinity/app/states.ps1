function sd-appStates-save {
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $stateName
    )
    
    $project = sd-project-getCurrent
    
    $dbName = sd-db-getNameFromDataConfig
    $db = sql-get-dbs | Where-Object { $_.Name -eq $dbName }
    if (-not $dbName -or -not $db) {
        throw "Current app is not initialized with a database. The configured database does not exist or no database is configured."
    }

    $statePath = "$($project.webAppPath)/dev-tool/states/$stateName"
    if (Test-Path $statePath) {
        unlock-allFiles -path $statePath
        Remove-Item -Force -Recurse -Path $statePath
    }

    $appDataStatePath = "$statePath/App_Data"
    New-Item $appDataStatePath -ItemType Directory > $null

    $Acl = Get-Acl -Path $statePath
    $Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("Everyone", "Full", "ContainerInherit,ObjectInherit", "None", "Allow")
    $Acl.SetAccessRule($Ar)
    Set-Acl $statePath $Acl

    $backupName = _getSqlBackupStateName -stateName $stateName
    Backup-SqlDatabase -ServerInstance $GLOBAL:sf.Config.sqlServerInstance -Database $dbName -BackupFile $backupName -Credential $(_getSqlCredentials) -Initialize
    
    $stateDataPath = "$statePath/data.xml"
    New-Item $stateDataPath > $null
    $stateData = New-Object XML
    $root = $stateData.CreateElement("root")
    $stateData.AppendChild($root) > $null
    $root.SetAttribute("dbName", $dbName)
    $stateData.Save($stateDataPath) > $null

    _appData-copy -dest $appDataStatePath
}

function sd-appStates-restore {
    Param(
        [string]$stateName,
        [bool]$force = $false
    )

    $project = sd-project-getCurrent

    if (!$stateName) {
        $stateName = _selectAppState -context $context
    }

    if (!$stateName) {
        return
    }

    sd-iisAppPool-Reset
    if ($force) {
        sd-sol-unlockAllFiles
    }
    
    $statesPath = _getStatesPath
    $statePath = "${statesPath}/$stateName"
    $dbName = ([xml](Get-Content "$statePath/data.xml")).root.dbName
    
    sql-delete-database -dbName $dbName
    $backupName = _getSqlBackupStateName -stateName $stateName
    Restore-SqlDatabase -ServerInstance $GLOBAL:sf.config.sqlServerInstance -Database $dbName -BackupFile $backupName -Credential $(_getSqlCredentials)

    $appDataStatePath = "$statePath/App_Data"
    $appDataPath = "$($project.webAppPath)/App_Data"
    if (-not (Test-Path $appDataPath)) {
        New-Item $appDataPath -ItemType Directory > $null
    }
    
    _appData-restore "$appDataStatePath/*"
}

function sd-appStates-remove ($stateName) {
    if ([string]::IsNullOrEmpty($stateName)) {
        $stateName = _selectAppState
    }

    if (-not $stateName) {
        return
    }

    $statesPath = _getStatesPath
    if ($statesPath) {
        $statePath = "${statesPath}/$stateName"
        Remove-Item $statePath -Force -ErrorAction SilentlyContinue -Recurse
    }
}

function sd-appStates-removeAll {
    $statesPath = _getStatesPath
    if (Test-Path $statesPath) {
        $states = Get-ChildItem $statesPath
        foreach ($state in $states) {
            sd-appStates-remove $state.Name
        }
    }
}

function _selectAppState {
    $statesPath = _getStatesPath
    $states = Get-Item "${statesPath}/*"
    if (-not $states) {
        Write-Warning "No states."
        return
    }
    
    $i = 0
    foreach ($state in $states) {
        Write-Host :"$i : $($state.Name)"
        $i++
    }

    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose state'
        $stateName = $states[$choice].Name
        if ($null -ne $stateName) {
            break;
        }
    }

    return $stateName
}

function _getSqlBackupStateName {
    param (
        [Parameter(Mandatory = $true)]$stateName
    )
    
    [SfProject]$context = sd-project-getCurrent
    return "$($context.id)_$stateName.bak"
}

function _getSqlCredentials {
    $password = ConvertTo-SecureString $GLOBAL:sf.Config.sqlPass -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($GLOBAL:sf.Config.sqlUser, $password)
    $credential
}

function _getStatesPath {
    $context = sd-project-getCurrent
    $path = "$($context.webAppPath)/dev-tool"
    
    if (!(Test-Path $path)) {
        New-Item $path -ItemType Directory -ErrorAction Stop
    }

    $path = "$path/states"
    if (-not (Test-Path $path)) {
        New-Item $path -ItemType Directory -ErrorAction Stop
    }
    
    return $path
}

function _appData-copy ($dest) {
    [SfProject]$project = sd-project-getCurrent

    $src = "$($project.webAppPath)\App_Data\*"
    Copy-Item -Path $src -Destination $dest -Recurse -Force -Confirm:$false -Exclude $(_getSitefinityAppDataExcludeFilter)
}

function _appData-restore ($src) {
    [SfProject]$context = sd-project-getCurrent
    $webAppPath = $context.webAppPath

    _appData-remove
    Copy-Item -Path $src -Destination "$webAppPath\App_Data" -Confirm:$false -Recurse -Force -Exclude $(_getSitefinityAppDataExcludeFilter) -ErrorVariable $errors -ErrorAction SilentlyContinue  # exclude is here for backward comaptibility
    if ($errors) {
        Write-Information "Some files could not be cleaned in AppData, because they might be in use."
    }
}

function _appData-remove {
    [SfProject]$context = sd-project-getCurrent
    $webAppPath = $context.webAppPath

    $toDelete = Get-ChildItem "${webAppPath}\App_Data" -Recurse -Force -Exclude $(_getSitefinityAppDataExcludeFilter) -File
    $toDelete | ForEach-Object { unlock-allFiles -path $_.FullName }
    $errors
    $toDelete | Remove-Item -Force -ErrorAction SilentlyContinue -ErrorVariable +errors
    if ($errors) {
        Write-Information "Some files in AppData folder could not be cleaned up, perhaps in use?"
    }
    
    # clean empty dirs
    _clean-emptyDirs -path "${webAppPath}\App_Data"
}

function _getSitefinityAppDataExcludeFilter {
    "*.pfx"
    "*.lic"
}
