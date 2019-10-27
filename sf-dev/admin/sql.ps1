function sql-delete-database {
    Param (
        [Parameter(Mandatory = $true)][string] $dbName,
        [string] $user,
        [string] $pass,
        [string] $sqlServerInstance
    )

    $Databases = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("SELECT * from sys.databases where NAME = '$dbName'") -Username $user -Password $pass

    ForEach ($Database in $Databases) { 
        Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query (
            "alter database [" + $Database.Name + "] set single_user with rollback immediate
            DROP DATABASE [" + $Database.Name + "]") -Username $user -Password $pass
    }
}

function sql-rename-database {
    Param (
        [Parameter(Mandatory = $true)][string] $oldName,
        [Parameter(Mandatory = $true)][string] $newName,
        [string] $user,
        [string] $pass,
        [string] $sqlServerInstance
    )

    $Databases = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("SELECT * from sys.databases where NAME = '$oldName'") -Username $user -Password $pass

    ForEach ($Database in $Databases) { 
        Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query (
            "alter database [" + $Database.Name + "] set single_user with rollback immediate
            EXEC sp_renamedb '$oldName', '$newName'
            ALTER DATABASE [$newName] SET MULTI_USER") -Username $user -Password $pass
    }
}

function sql-get-dbs {
    Param (
        [Parameter(Mandatory = $true)][string] $user,
        [Parameter(Mandatory = $true)][string] $pass,
        [string] $sqlServerInstance
    )

    $Databases = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("SELECT * from sys.databases") -Username $user -Password $pass

    return $Databases
}

function sql-get-items {
    Param($dbName, $tableName, $selectFilter, $whereFilter,
        [string] $user,
        [string] $pass,
        [string] $sqlServerInstance
    )

    $result = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("
        SELECT $selectFilter
        FROM [${dbName}].[dbo].[${tableName}]
        WHERE $whereFilter") -Username $user -Password $pass

    return $result
}

function sql-update-items {
    Param($dbName, $tableName, $value, $whereFilter,
        [string] $user,
        [string] $pass,
        [string] $sqlServerInstance
    )

    $result = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query "
        UPDATE [${dbName}].[dbo].[${tableName}]
        SET ${value}
        WHERE $whereFilter" -Username $user -Password $pass

    return $result
}

function sql-insert-items {
    Param($dbName, $tableName, $columns, $values,
        [string] $user,
        [string] $pass,
        [string] $sqlServerInstance)

    $result = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query "
        INSERT INTO [${dbName}].[dbo].[${tableName}] ($columns)
        VALUES (${values})" -Username $user -Password $pass

    return $result
}

function sql-delete-items {
    Param($dbName, $tableName, $whereFilter,
        [string] $user,
        [string] $pass,
        [string] $sqlServerInstance)

    Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("
        DELETE FROM [${dbName}].[dbo].[${tableName}]
        WHERE $whereFilter") -Username $user -Password $pass
}

function sql-test-isDbNameDuplicate {
    Param(
        [string]$dbName,
        [string] $user,
        [string] $pass,
        [string] $sqlServerInstance
    )

    $existingDbs = @(sql-get-dbs -user $user -pass $pass -sqlServerInstance $sqlServerInstance)
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
        [string]$targetDbName,
        [string] $user,
        [string] $pass,
        [string] $sqlServerInstance
    )
    #import SQL Server module

    #your SQL Server Instance Name
    $connection = [Microsoft.SqlServer.Management.Common.ServerConnection]::new()
    $connection.ServerInstance = $sqlServerInstance
    $connection.LoginSecure = $false
    $connection.Login = $user
    $connection.Password = $pass
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
    $ObjTransfer.DestinationServer = $sqlServerInstance
    $ObjTransfer.DestinationLoginSecure = $false
    $ObjTransfer.CopySchema = $true
    $ObjTransfer.DestinationLogin = $user
    $ObjTransfer.DestinationPassword = $pass

    #if you wish to just generate the copy script
    #just script out the transfer
    $ObjTransfer.ScriptTransfer()

    #When you are ready to bring the data and schema over,
    #you can use the TransferData method
    $ObjTransfer.TransferData()
}

class SqlClient {
    [string] hidden $user
    [string] hidden $pass
    [string] hidden $server

    [void] Configure([string]$user, [string]$pass, [string]$server) {
        $this.user = $user
        $this.pass = $pass
        $this.server = $server
    }

    [System.Object[]] GetDbs() {
        return sql-get-dbs -user $this.user -pass $this.pass -sqlServerInstance $this.server
    }

    [void] CopyDb([string] $source, [string] $target) {
        sql-copy-db -SourceDBName $source -targetDbName $target -user $this.user -pass $this.pass -sqlServerInstance $this.server
    }

    [void] Delete([string]$dbName) {
        sql-delete-database -dbName $dbName -user $this.user -pass $this.pass -sqlServerInstance $this.server
    }

    [System.Object[]] GetItems([string]$db, [string]$table, [string]$where, [string]$select) {
        return sql-get-items -dbName $db -tableName $table -selectFilter $select -whereFilter $where -user $this.user -pass $this.pass -sqlServerInstance $this.server
    }

    [void] UpdateItems([string]$db, [string]$table, [string]$where, [string]$value) {
        sql-update-items -dbName $db -tableName $table -value $value -whereFilter $where -user $this.user -pass $this.pass -sqlServerInstance $this.server
    }
    
    [void] InsertItems([string]$db, [string]$table, [string]$columns, [string]$values) {
        sql-insert-items -dbName $db -tableName $table -values $values -columns $columns -user $this.user -pass $this.pass -sqlServerInstance $this.server
    }

    [bool] IsDuplicate([string]$dbName) {
        return sql-test-isDbNameDuplicate -dbName $dbName -user $this.user -pass $this.pass -sqlServerInstance $this.server
    }
}

$sql = [SqlClient]::new()
$Global:sf | Add-Member -MemberType NoteProperty -TypeName SqlClient -Name 'sql' -Value $sql
