function sf-save-appState {
    $context = _get-selectedProject
    
    $dbName = sf-get-appDbName
    if (-not $dbName) {
        throw "Current app is not initialized with a database. No databse name found in dataConfig.config"
    }
    
    while ($true) {
        $stateName = Read-Host -Prompt "Enter state name:"
        $statePath = "$($context.webAppPath)/sf-dev-tool/states/$stateName"
        $appDataStatePath = "$statePath/App_Data"
        if (-not (Test-Path $appDataStatePath)) {
            New-Item $appDataStatePath -ItemType Directory > $null
            break;
        }
    }

    $Acl = Get-Acl $statePath
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

    $appDataPath = "$($context.webAppPath)/App_Data"
    Copy-Item "$appDataPath/*" $appDataStatePath -Recurse
    
}

function _sf-get-statesPath {
    $context = _get-selectedProject
    return "$($context.webAppPath)/sf-dev-tool/states"
}

function sf-restore-appState {
    $context = _get-selectedProject
    $stateName = _sf-select-appState
    sf-reset-pool
    $statesPath = _sf-get-statesPath
    $statePath = "${statesPath}/$stateName"
    $dbName = ([xml](Get-Content "$statePath/data.xml")).root.dbName
    sql-delete-database $dbName
    Restore-SqlDatabase -ServerInstance $sqlServerInstance -Database $dbName -BackupFile "$statePath/$dbName.bak"

    $appDataStatePath = "$statePath/App_Data"
    $appDataPath = "$($context.webAppPath)/App_Data"
    if (Test-Path $appDataPath) {
        Remove-Item "$appDataPath/*" -Force -ErrorAction SilentlyContinue -Recurse
    }
    else {
        New-Item $appDataPath -ItemType Directory > $null
    }
    
    sf-reset-pool
    Copy-Item "$appDataStatePath/*" $appDataPath -Recurse -Force
}

function sf-delete-appState ($stateName) {
    if ([string]::IsNullOrEmpty($stateName)) {
        $stateName = _sf-select-appState
    }

    $statesPath = _sf-get-statesPath
    if ($statesPath) {
        $statePath = "${statesPath}/$stateName"
        Remove-Item $statePath -Force -ErrorAction SilentlyContinue -Recurse    
    }
}

function sf-delete-allAppStates {
    $statesPath = _sf-get-statesPath
    if (Test-Path $statesPath) {
        $states = Get-Item "${statesPath}/*"
        foreach ($state in $states) {
            sf-delete-appState $state.Name
        }
    }
}

function _sf-select-appState {
    $statesPath = _sf-get-statesPath
    $states = Get-Item "${statesPath}/*"
    
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
