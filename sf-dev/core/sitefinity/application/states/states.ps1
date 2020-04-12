$Script:stateCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )

    $possibleValues = sf-appStates-get | select -ExpandProperty name
    if ($wordToComplete) {
        $possibleValues = $possibleValues | Where-Object {
            $_ -like "$wordToComplete*"
        }
    }

    $possibleValues
}

function sf-appStates-save {
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $stateName
    )

    $project = sf-project-getCurrent

    $dbName = sf-db-getNameFromDataConfig
    $db = sql-get-dbs | Where-Object { $_.Name -eq $dbName }
    if (-not $dbName -or -not $db) {
        throw "Current app is not initialized with a database. The configured database does not exist or no database is configured."
    }

    $statePath = "$($project.webAppPath)\dev-tool\states\$stateName"
    if (Test-Path $statePath) {
        unlock-allFiles -path $statePath
        Remove-Item -Force -Recurse -Path $statePath
    }

    $appDataStatePath = "$statePath\App_Data"
    New-Item $appDataStatePath -ItemType Directory > $null

    $Acl = Get-Acl -Path $statePath
    $Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("Everyone", "Full", "ContainerInherit,ObjectInherit", "None", "Allow")
    $Acl.SetAccessRule($Ar)
    Set-Acl $statePath $Acl

    $backupName = _getSqlBackupStateName -stateName $stateName
    Backup-SqlDatabase -ServerInstance $GLOBAL:sf.Config.sqlServerInstance -Database $dbName -BackupFile $backupName -Credential $(_getSqlCredentials) -Initialize

    $stateDataPath = "$statePath\data.xml"
    New-Item $stateDataPath > $null
    $stateData = New-Object XML
    $root = $stateData.CreateElement("root")
    $stateData.AppendChild($root) > $null
    $root.SetAttribute("dbName", $dbName)
    $stateData.Save($stateDataPath) > $null

    _appData-copy -dest $appDataStatePath
}

Register-ArgumentCompleter -CommandName sf-appStates-save -ParameterName stateName -ScriptBlock $stateCompleter

function sf-appStates-restore {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)][string]$stateName,
        [bool]$force = $false
    )

    process {
        $project = sf-project-getCurrent

        if (!$stateName) {
            $stateName = _selectAppState -context $context
        }

        if (!$stateName) {
            return
        }

        sf-iisAppPool-Reset
        if ($force) {
            sf-sol-unlockAllFiles
        }

        $statesPath = _getStatesPath
        $statePath = "${statesPath}/$stateName"
        $dbName = ([xml](Get-Content "$statePath\data.xml")).root.dbName

        sql-delete-database -dbName $dbName
        $backupName = _getSqlBackupStateName -stateName $stateName
        Restore-SqlDatabase -ServerInstance $GLOBAL:sf.config.sqlServerInstance -Database $dbName -BackupFile $backupName -Credential $(_getSqlCredentials)

        $appDataStatePath = "$statePath\App_Data"
        $appDataPath = "$($project.webAppPath)\App_Data"
        if (-not (Test-Path $appDataPath)) {
            New-Item $appDataPath -ItemType Directory > $null
        }

        _appData-restore "$appDataStatePath/*"
    }
}

Register-ArgumentCompleter -CommandName sf-appStates-restore -ParameterName stateName -ScriptBlock $stateCompleter

function sf-appStates-remove {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]$stateName
    )
        
    process {
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
}

Register-ArgumentCompleter -CommandName sf-appStates-remove -ParameterName stateName -ScriptBlock $stateCompleter

function sf-appStates-removeAll {
    sf-appStates-get | sf-appStates-remove
}

# returns object with name and path
function sf-appStates-get {
    $statesPath = _getStatesPath
    $result = Get-ChildItem $statesPath -Directory | % { 
        [PSCustomObject]@{
            name = $_.Name;
            path = $_.FullName
        }
    }

    $result
}

function _selectAppState {
    $states = sf-appStates-get
    if (-not $states) {
        Write-Warning "No states."
        return
    }

    $i = 0
    foreach ($state in $states) {
        Write-Host :"$i : $($state.name)"
        $i++
    }

    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose state'
        $stateName = $states[$choice].name
        if ($null -ne $stateName) {
            break;
        }
    }

    return $stateName
}

function _getStatesPath {
    $context = sf-project-getCurrent
    $path = "$($context.webAppPath)/dev-tool"

    if (!(Test-Path $path)) {
        New-Item $path -ItemType Directory -ErrorAction Stop
    }

    $path = "$path\states"
    if (-not (Test-Path $path)) {
        New-Item $path -ItemType Directory -ErrorAction Stop
    }

    return $path
}
