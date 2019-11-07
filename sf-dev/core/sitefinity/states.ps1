function states-save {
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $stateName
    )
    
    $project = proj-getCurrent
    
    $dbName = db-getNameFromDataConfig
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
    Backup-SqlDatabase -ServerInstance $GLOBAL:Sf.Config.sqlServerInstance -Database $dbName -BackupFile $backupName -Credential $(_getSqlCredentials) -Initialize
    
    $stateDataPath = "$statePath/data.xml"
    New-Item $stateDataPath > $null
    $stateData = New-Object XML
    $root = $stateData.CreateElement("root")
    $stateData.AppendChild($root) > $null
    $root.SetAttribute("dbName", $dbName)
    $stateData.Save($stateDataPath) > $null

    _appData-copy -dest $appDataStatePath
}

function states-restore {
    Param(
        [string]$stateName,
        [bool]$force = $false
    )

    $project = proj-getCurrent

    if (!$stateName) {
        $stateName = _selectAppState -context $context
    }

    if (!$stateName) {
        return
    }

    pool-reset
    if ($force) {
        sol-unlockAllFiles
    }
    
    $statesPath = _getStatesPath
    $statePath = "${statesPath}/$stateName"
    $dbName = ([xml](Get-Content "$statePath/data.xml")).root.dbName
    
    sql-delete-database -dbName $dbName
    $backupName = _getSqlBackupStateName -stateName $stateName
    Restore-SqlDatabase -ServerInstance $GLOBAL:Sf.config.sqlServerInstance -Database $dbName -BackupFile $backupName -Credential $(_getSqlCredentials)

    $appDataStatePath = "$statePath/App_Data"
    $appDataPath = "$($project.webAppPath)/App_Data"
    if (-not (Test-Path $appDataPath)) {
        New-Item $appDataPath -ItemType Directory > $null
    }
    
    _appData-restore "$appDataStatePath/*"
}

function states-remove ($stateName) {
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

function states-removeAll {
    $statesPath = _getStatesPath
    if (Test-Path $statesPath) {
        $states = Get-ChildItem $statesPath
        foreach ($state in $states) {
            states-remove $state.Name
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
    
    [SfProject]$context = proj-getCurrent
    return "$($context.id)_$stateName.bak"
}

function _getSqlCredentials {
    $password = ConvertTo-SecureString $GLOBAL:Sf.Config.sqlPass -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($GLOBAL:Sf.Config.sqlUser, $password)
    $credential
}

function _getStatesPath {
    $context = proj-getCurrent
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
