function sf-new-appState {
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $stateName,
        [SfProject]$project
    )
    
    if (!$project) {
        $project = _get-selectedProject
    }
    
    $dbName = sf-get-appDbName
    [SqlClient]$sqlClient = _get-sqlClient
    $db = $sqlClient.GetDbs() | Where-Object { $_.Name -eq $dbName }
    if (-not $dbName -or -not $db) {
        throw "Current app is not initialized with a database. The configured database does not exist or no database is configured."
    }

    $statePath = "$($project.webAppPath)/sf-dev-tool/states/$stateName"
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

    $backupName = get-sqlBackupStateName -stateName $stateName
    Backup-SqlDatabase -ServerInstance $Script:sqlServerInstance -Database $dbName -BackupFile $backupName -Credential $(get-sqlCredentials)
    
    $stateDataPath = "$statePath/data.xml"
    New-Item $stateDataPath > $null
    $stateData = New-Object XML
    $root = $stateData.CreateElement("root")
    $stateData.AppendChild($root) > $null
    $root.SetAttribute("dbName", $dbName)
    $stateData.Save($stateDataPath) > $null

    copy-sfRuntimeFiles -dest $appDataStatePath
}

function sf-restore-appState {
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $stateName,
        [bool]$force = $false,
        [SfProject]$project)

    if (!$project) {
        $project = _get-selectedProject
    }

    if (!$stateName) {
        $stateName = select-appState
    }

    if (!$stateName) {
        return
    }
    
    sf-reset-pool
    if ($force) {
        sf-unlock-allFiles
    }
    
    $statesPath = get-statesPath
    $statePath = "${statesPath}/$stateName"
    $dbName = ([xml](Get-Content "$statePath/data.xml")).root.dbName
    [SqlClient]$sql = _get-sqlClient
    $sql.Delete($dbName)
    $backupName = get-sqlBackupStateName -stateName $stateName
    Restore-SqlDatabase -ServerInstance $sqlServerInstance -Database $dbName -BackupFile $backupName -Credential $(get-sqlCredentials)

    $appDataStatePath = "$statePath/App_Data"
    $appDataPath = "$($project.webAppPath)/App_Data"
    if (-not (Test-Path $appDataPath)) {
        New-Item $appDataPath -ItemType Directory > $null
    }
    
    restore-sfRuntimeFiles "$appDataStatePath/*"
}

function get-statesPath ([SfProject]$context) {
    if (!$context) {
        $context = _get-selectedProject
    }

    $path = "$($context.webAppPath)/sf-dev-tool/states"
    if (-not (Test-Path $path)) {
        New-Item $path -ItemType Directory
    }
    
    return $path
}

function sf-delete-appState ($stateName, [SfProject]$context) {
    if ([string]::IsNullOrEmpty($stateName)) {
        $stateName = select-appState -context $context
    }

    if (-not $stateName) {
        return
    }

    $statesPath = get-statesPath -context $context
    if ($statesPath) {
        $statePath = "${statesPath}/$stateName"
        Remove-Item $statePath -Force -ErrorAction SilentlyContinue -Recurse
    }
}

function sf-delete-allAppStates ([SfProject]$context) {
    $statesPath = get-statesPath -context $context
    if (Test-Path $statesPath) {
        $states = Get-ChildItem $statesPath
        foreach ($state in $states) {
            sf-delete-appState $state.Name -context $context
        }
    }
}

function select-appState ([SfProject]$context) {
    $statesPath = get-statesPath -context $context
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

function get-sqlBackupStateName {
    param (
        [Parameter(Mandatory=$true)]$stateName
    )
    
    [SfProject]$context = _get-selectedProject
    return "$($context.id)_$stateName.bak"
}

function get-sqlCredentials {
    $password = ConvertTo-SecureString $Script:sqlPass -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($Script:sqlUser, $password)
    $credential
}