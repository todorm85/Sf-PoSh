function sf-new-appState {
    Param(
        [Parameter(Mandatory=$true)]
        $stateName
    )
    
    $context = _get-selectedProject
    
    $dbName = sf-get-appDbName
    $db = Get-SqlDatabase -Name $dbName -ServerInstance $sqlServerInstance 
    if (-not $dbName -or -not $db) {
        throw "Current app is not initialized with a database. The configured database does not exist or no database is configured."
    }

    $statePath = "$($context.webAppPath)/sf-dev-tool/states/$stateName"
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

    Backup-SqlDatabase -ServerInstance $sqlServerInstance -Database $dbName -BackupFile "$statePath/$dbName.bak"
    
    $stateDataPath = "$statePath/data.xml"
    New-Item $stateDataPath > $null
    $stateData = New-Object XML
    $root = $stateData.CreateElement("root")
    $stateData.AppendChild($root) > $null
    $root.SetAttribute("dbName", $dbName)
    $stateData.Save($stateDataPath) > $null

    copy-sfRuntimeFiles -dest $appDataStatePath
}

function get-statesPath {
    $context = _get-selectedProject
    $path = "$($context.webAppPath)/sf-dev-tool/states"
    if (-not (Test-Path $path)) {
        New-Item $path -ItemType Directory
    }
    
    return $path
}

function sf-restore-appState ($stateName, $force = $false) {
    $context = _get-selectedProject
    if (-not $stateName) {
        $stateName = select-appState
    }

    if (-not $stateName) {
        return
    }
    
    sf-reset-pool
    if ($force) {
        sf-unlock-allFiles
    }
    
    $statesPath = get-statesPath
    $statePath = "${statesPath}/$stateName"
    $dbName = ([xml](Get-Content "$statePath/data.xml")).root.dbName
    sql-delete-database $dbName
    Restore-SqlDatabase -ServerInstance $sqlServerInstance -Database $dbName -BackupFile "$statePath/$dbName.bak"

    $appDataStatePath = "$statePath/App_Data"
    $appDataPath = "$($context.webAppPath)/App_Data"
    if (-not (Test-Path $appDataPath)) {
        New-Item $appDataPath -ItemType Directory > $null
    }
    
    restore-sfRuntimeFiles "$appDataStatePath/*"
}

function sf-delete-appState ($stateName) {
    if ([string]::IsNullOrEmpty($stateName)) {
        $stateName = select-appState
    }

    if (-not $stateName) {
        return
    }

    $statesPath = get-statesPath
    if ($statesPath) {
        $statePath = "${statesPath}/$stateName"
        Remove-Item $statePath -Force -ErrorAction SilentlyContinue -Recurse    
    }
}

function sf-delete-allAppStates {
    $statesPath = get-statesPath
    if (Test-Path $statesPath) {
        $states = Get-Item "${statesPath}/*"
        foreach ($state in $states) {
            sf-delete-appState $state.Name
        }
    }
}

function select-appState {
    $statesPath = get-statesPath
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
