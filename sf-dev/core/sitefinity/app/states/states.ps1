$Script:stateCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )

    $possibleValues = sd-appStates-get | select -ExpandProperty name
    if ($wordToComplete) {
        $possibleValues = $possibleValues | Where-Object {
            $_ -like "$wordToComplete*"
        }
    }

    $possibleValues
}

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

Register-ArgumentCompleter -CommandName sd-appStates-save -ParameterName stateName -ScriptBlock $stateCompleter

function sd-appStates-restore {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)][string]$stateName,
        [bool]$force = $false
    )

    process {
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

Register-ArgumentCompleter -CommandName sd-appStates-restore -ParameterName stateName -ScriptBlock $stateCompleter

function sd-appStates-remove {
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

Register-ArgumentCompleter -CommandName sd-appStates-remove -ParameterName stateName -ScriptBlock $stateCompleter

function sd-appStates-removeAll {
    sd-appStates-get | sd-appStates-remove
}

# returns object with name and path
function sd-appStates-get {
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
    $states = _getStates
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
    $context = sd-project-getCurrent
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
