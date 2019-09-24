function Save-AppState {
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $stateName,
        [SfProject]$project
    )
    
    if (!$project) {
        $project = Get-CurrentProject
    }
    
    $dbName = Get-AppDbName
    $db = $tokoAdmin.sql.GetDbs() | Where-Object { $_.Name -eq $dbName }
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

    $backupName = _get-sqlBackupStateName -stateName $stateName
    Backup-SqlDatabase -ServerInstance $GLOBAL:Sf.Config.sqlServerInstance -Database $dbName -BackupFile $backupName -Credential $(_get-sqlCredentials) -Initialize
    
    $stateDataPath = "$statePath/data.xml"
    New-Item $stateDataPath > $null
    $stateData = New-Object XML
    $root = $stateData.CreateElement("root")
    $stateData.AppendChild($root) > $null
    $root.SetAttribute("dbName", $dbName)
    $stateData.Save($stateDataPath) > $null

    _copy-sfRuntimeFiles -dest $appDataStatePath
}

function Restore-AppState {
    Param(
        [string]$stateName,
        [bool]$force = $false,
        [SfProject]$project)

    if (!$project) {
        $project = Get-CurrentProject
    }

    if ([string]::IsNullOrEmpty($stateName)) {
        $stateName = _select-appState -context $context
    }

    Reset-Pool
    if ($force) {
         Unlock-AllProjectFiles
    }
    
    $statesPath = _get-statesPath
    $statePath = "${statesPath}/$stateName"
    $dbName = ([xml](Get-Content "$statePath/data.xml")).root.dbName
    
    $tokoAdmin.sql.Delete($dbName)
    $backupName = _get-sqlBackupStateName -stateName $stateName
    Restore-SqlDatabase -ServerInstance $GLOBAL:Sf.config.sqlServerInstance -Database $dbName -BackupFile $backupName -Credential $(_get-sqlCredentials)

    $appDataStatePath = "$statePath/App_Data"
    $appDataPath = "$($project.webAppPath)/App_Data"
    if (-not (Test-Path $appDataPath)) {
        New-Item $appDataPath -ItemType Directory > $null
    }
    
    _restore-sfRuntimeFiles "$appDataStatePath/*"
}

function Delete-AppState ($stateName, [SfProject]$context) {
    if ([string]::IsNullOrEmpty($stateName)) {
        $stateName = _select-appState -context $context
    }

    if (-not $stateName) {
        return
    }

    $statesPath = _get-statesPath -context $context
    if ($statesPath) {
        $statePath = "${statesPath}/$stateName"
        Remove-Item $statePath -Force -ErrorAction SilentlyContinue -Recurse
    }
}

function Delete-AllAppStates ([SfProject]$context) {
    $statesPath = _get-statesPath -context $context
    if (Test-Path $statesPath) {
        $states = Get-ChildItem $statesPath
        foreach ($state in $states) {
            Delete-AppState $state.Name -context $context
        }
    }
}

function _select-appState ([SfProject]$context) {
    $statesPath = _get-statesPath -context $context
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

function _get-sqlBackupStateName {
    param (
        [Parameter(Mandatory=$true)]$stateName
    )
    
    [SfProject]$context = Get-CurrentProject
    return "$($context.id)_$stateName.bak"
}

function _get-sqlCredentials {
    $password = ConvertTo-SecureString $GLOBAL:Sf.Config.sqlPass -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($GLOBAL:Sf.Config.sqlUser, $password)
    $credential
}

function _get-statesPath ([SfProject]$context) {
    if (!$context) {
        $context = Get-CurrentProject
    }

    $path = "$($context.webAppPath)/sf-dev-tool/states"
    if (-not (Test-Path $path)) {
        New-Item $path -ItemType Directory
    }
    
    return $path
}
