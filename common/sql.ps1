Param (
        [Parameter(Mandatory=$true)][string] $ServerInstance
    )

    Import-Module SQLPS -DisableNameChecking

function sql-delete-database {
    Param (
            [Parameter(Mandatory=$true)][string] $dbName
        )


    $Databases = Invoke-SQLcmd -ServerInstance $ServerInstance -Query ("SELECT * from sys.databases where NAME = '$dbName'")

    ForEach ($Database in $Databases)
    { 
        Invoke-SQLcmd -ServerInstance $ServerInstance -Query (
            "alter database [" + $Database.Name + "] set single_user with rollback immediate
            DROP DATABASE [" + $Database.Name + "]")
    }
}

function sql-get-dbs {
    $Databases = Invoke-SQLcmd -ServerInstance $ServerInstance -Query ("SELECT * from sys.databases")

    return $Databases
}

function sql-get-items {
    Param($dbName, $tableName, $selectFilter, $whereFilter)

    $result = Invoke-SQLcmd -ServerInstance $ServerInstance -Query ("
        SELECT $selectFilter
        FROM [${dbName}].[dbo].[${tableName}]
        WHERE $whereFilter")

    return $result
}

function sql-update-items {
    Param($dbName, $tableName, $value, $whereFilter)

    $result = Invoke-SQLcmd -ServerInstance $ServerInstance -Query "
        UPDATE [${dbName}].[dbo].[${tableName}]
        SET dta='${value}'
        WHERE $whereFilter"

    return $result
}

function sql-delete-items {
    Param($dbName, $tableName, $whereFilter)

    $result = Invoke-SQLcmd -ServerInstance $ServerInstance -Query ("
        DELETE FROM [${dbName}].[dbo].[${tableName}]
        WHERE $whereFilter")
}

function sql-test-isDbNameDuplicate {
    Param($dbName)

    $existingDbs = @(sql-get-dbs)
    $exists = $false
    ForEach ($db in $existingDbs) {
        if ($db.name -eq $dbName) {
            $exists = $true
            break;
        }
    }

    return $exists
}