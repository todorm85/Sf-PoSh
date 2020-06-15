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

    $project = sf-project-get

    $dbName = sf-db-getNameFromDataConfig
    $db = sql-get-dbs | Where-Object { $_.Name -eq $dbName }
    if (-not $dbName -or -not $db) {
        throw "Current app is not initialized with a database. The configured database does not exist or no database is configured."
    }

    $statePath = "$(_getStatesPath)\$stateName"
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

Register-ArgumentCompleter -CommandName sf-appStates-save -ParameterName stateName -ScriptBlock $Script:stateCompleter

function sf-appStates-restore {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$stateName,
        [bool]$force = $false
    )

    process {
        $project = sf-project-get

        if (!$stateName) {
            throw "Empty state name."
        }

        sf-iisAppPool-Reset
        if ($force) {
            sf-sol-unlockAllFiles
        }

        $statesPath = _getStatesPath
        $statePath = "${statesPath}\$stateName"
        $dbName = ([xml](Get-Content "$statePath\data.xml")).root.dbName

        sql-delete-database -dbName $dbName
        $backupName = _getSqlBackupStateName -stateName $stateName
        Restore-SqlDatabase -ServerInstance $GLOBAL:sf.config.sqlServerInstance -Database $dbName -BackupFile $backupName -Credential $(_getSqlCredentials)

        $appDataStatePath = "$statePath\App_Data"
        $appDataPath = "$($project.webAppPath)\App_Data"
        if (-not (Test-Path $appDataPath)) {
            New-Item $appDataPath -ItemType Directory > $null
        }

        _appData-restore "$appDataStatePath\*"
    }
}

Register-ArgumentCompleter -CommandName sf-appStates-restore -ParameterName stateName -ScriptBlock $Script:stateCompleter

function sf-appStates-remove {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]$name
    )
        
    process {
        if (-not $name) {
            return
        }

        $statesPath = _getStatesPath
        if ($statesPath) {
            $statePath = "${statesPath}/$name"
            Remove-Item $statePath -Force -ErrorAction SilentlyContinue -Recurse
        }
    }
}

Register-ArgumentCompleter -CommandName sf-appStates-remove -ParameterName name -ScriptBlock $Script:stateCompleter

# returns object with name and path
function sf-appStates-get {
    $statesPath = _getStatesPath
    $result = Get-ChildItem $statesPath -Directory | % { 
        [PSCustomObject]@{
            name = $_.Name;
            date = $_.LastWriteTime;
        }
    }

    $result
}

function _getStatesPath {
    $context = sf-project-get
    $path = "$($context.webAppPath)\sf-posh\states"

    if (!(Test-Path $path)) {
        New-Item $path -ItemType Directory -ErrorAction Stop > $null
    }

    return $path
}
