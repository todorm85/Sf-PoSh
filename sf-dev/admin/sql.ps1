function sql-delete-database {
    Param (
        [Parameter(Mandatory = $true)][string] $dbName
    )

    $Databases = Invoke-SQLcmd -ServerInstance $GLOBAL:sf.config.sqlServerInstance -Query ("SELECT * from sys.databases where NAME = '$dbName'") -Username $GLOBAL:sf.config.sqlUser -Password $GLOBAL:sf.config.sqlPass

    ForEach ($Database in $Databases) { 
        Invoke-SQLcmd -ServerInstance $GLOBAL:sf.config.sqlServerInstance -Query (
            "alter database [" + $Database.Name + "] set single_user with rollback immediate
            DROP DATABASE [" + $Database.Name + "]") -Username $GLOBAL:sf.config.sqlUser -Password $GLOBAL:sf.config.sqlPass
    }
}

function sql-rename-database {
    Param (
        [Parameter(Mandatory = $true)][string] $oldName,
        [Parameter(Mandatory = $true)][string] $newName
    )

    $Databases = Invoke-SQLcmd -ServerInstance $GLOBAL:sf.config.sqlServerInstance -Query ("SELECT * from sys.databases where NAME = '$oldName'") -Username $GLOBAL:sf.config.sqlUser -Password $GLOBAL:sf.config.sqlPass

    ForEach ($Database in $Databases) { 
        Invoke-SQLcmd -ServerInstance $GLOBAL:sf.config.sqlServerInstance -Query (
            "alter database [" + $Database.Name + "] set single_user with rollback immediate
            EXEC sp_renamedb '$oldName', '$newName'
            ALTER DATABASE [$newName] SET MULTI_USER") -Username $GLOBAL:sf.config.sqlUser -Password $GLOBAL:sf.config.sqlPass
    }
}

function sql-get-dbs {
    $Databases = Invoke-SQLcmd -ServerInstance $GLOBAL:sf.config.sqlServerInstance -Query ("SELECT * from sys.databases") -Username $GLOBAL:sf.config.sqlUser -Password $GLOBAL:sf.config.sqlPass

    return $Databases
}

function sql-get-items {
    Param($dbName, $tableName, $selectFilter, $whereFilter)

    $result = Invoke-SQLcmd -ServerInstance $GLOBAL:sf.config.sqlServerInstance -Query ("
        SELECT $selectFilter
        FROM [${dbName}].[dbo].[${tableName}]
        WHERE $whereFilter") -Username $GLOBAL:sf.config.sqlUser -Password $GLOBAL:sf.config.sqlPass

    return $result
}

function sql-update-items {
    Param($dbName, $tableName, $value, $whereFilter)

    $result = Invoke-SQLcmd -ServerInstance $GLOBAL:sf.config.sqlServerInstance -Query "
        UPDATE [${dbName}].[dbo].[${tableName}]
        SET ${value}
        WHERE $whereFilter" -Username $GLOBAL:sf.config.sqlUser -Password $GLOBAL:sf.config.sqlPass

    return $result
}

function sql-insert-items {
    Param(
        $dbName, $tableName, $columns, $values
    )

    $result = Invoke-SQLcmd -ServerInstance $GLOBAL:sf.config.sqlServerInstance -Query "
        INSERT INTO [${dbName}].[dbo].[${tableName}] ($columns)
        VALUES (${values})" -Username $GLOBAL:sf.config.sqlUser -Password $GLOBAL:sf.config.sqlPass

    return $result
}

function sql-delete-items {
    Param($dbName, $tableName, $whereFilter)

    Invoke-SQLcmd -ServerInstance $GLOBAL:sf.config.sqlServerInstance -Query ("
        DELETE FROM [${dbName}].[dbo].[${tableName}]
        WHERE $whereFilter") -Username $GLOBAL:sf.config.sqlUser -Password $GLOBAL:sf.config.sqlPass
}

function sql-test-isDbNameDuplicate {
    Param(
        [string]$dbName
    )

    $existingDbs = @(sql-get-dbs -user $GLOBAL:sf.config.sqlUser -pass $GLOBAL:sf.config.sqlPass -sqlServerInstance $GLOBAL:sf.config.sqlServerInstance)
    $exists = $false
    ForEach ($db in $existingDbs) {
        if ($db.name -eq $dbName) {
            $exists = $true
            break;
        }
    }

    return $exists
}

function sql-copy-db {
    Param(
        [string]$SourceDBName, 
        [string]$targetDbName
    )
    #import SQL Server module

    #your SQL Server Instance Name
    $connection = [Microsoft.SqlServer.Management.Common.ServerConnection]::new()
    $connection.ServerInstance = $GLOBAL:sf.config.sqlServerInstance
    $connection.LoginSecure = $false
    $connection.Login = $GLOBAL:sf.config.sqlUser
    $connection.Password = $GLOBAL:sf.config.sqlPass
    $Server = [Microsoft.SqlServer.Management.Smo.Server]::new($connection)

    #create SMO handle to your database
    $SourceDB = $Server.Databases[$SourceDBName]

    #create a database to hold the copy of your source database
    $CopyDBName = $targetDbName
    $CopyDB = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Database -ArgumentList $Server , $CopyDBName
    $CopyDB.Create()

    #Use SMO Transfer Class by specifying source database
    #you can specify properties you want either brought over or excluded, when the copy happens
    $ObjTransfer = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Transfer -ArgumentList $SourceDB
    $ObjTransfer.CopyAllTables = $true
    $ObjTransfer.CopyAllObjects = $true
    $ObjTransfer.Options.WithDependencies = $true
    $ObjTransfer.Options.ContinueScriptingOnError = $true
    $ObjTransfer.Options.Indexes = $true
    $ObjTransfer.Options.DriIndexes = $true
    $ObjTransfer.Options.DriPrimaryKey = $true
    $ObjTransfer.Options.DriUniqueKeys = $true
    $ObjTransfer.Options.Default = $true
    $ObjTransfer.Options.DriDefaults = $true
    $ObjTransfer.Options.DriAllKeys = $true
    $ObjTransfer.Options.DriAllConstraints = $true
    $ObjTransfer.Options.DriForeignKeys = $true
    $ObjTransfer.DestinationDatabase = $CopyDBName
    $ObjTransfer.DestinationServer = $GLOBAL:sf.config.sqlServerInstance
    $ObjTransfer.DestinationLoginSecure = $false
    $ObjTransfer.CopySchema = $true
    $ObjTransfer.DestinationLogin = $GLOBAL:sf.config.sqlUser
    $ObjTransfer.DestinationPassword = $GLOBAL:sf.config.sqlPass

    #if you wish to just generate the copy script
    #just script out the transfer
    $ObjTransfer.ScriptTransfer()

    #When you are ready to bring the data and schema over,
    #you can use the TransferData method
    $ObjTransfer.TransferData()
}