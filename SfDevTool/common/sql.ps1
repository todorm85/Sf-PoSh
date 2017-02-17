
function _sql-load-module {
    $mod = Get-Module SQLPS
    if ($null -eq $mod -or '' -eq $mod) {
        $oldLocation = Get-Location
        Import-Module SQLPS -DisableNameChecking
        Set-Location $oldLocation
    }
}

function sql-delete-database {
    Param (
            [Parameter(Mandatory=$true)][string] $dbName
        )

    _sql-load-module

    $Databases = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("SELECT * from sys.databases where NAME = '$dbName'")

    ForEach ($Database in $Databases)
    { 
        Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query (
            "alter database [" + $Database.Name + "] set single_user with rollback immediate
            DROP DATABASE [" + $Database.Name + "]")
    }
}

function sql-rename-database {
    Param (
            [Parameter(Mandatory=$true)][string] $oldName,
            [Parameter(Mandatory=$true)][string] $newName
        )

    _sql-load-module

    $Databases = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("SELECT * from sys.databases where NAME = '$oldName'")

    ForEach ($Database in $Databases)
    { 
        Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query (
            "alter database [" + $Database.Name + "] set single_user with rollback immediate
            EXEC sp_renamedb '$oldName', '$newName'
            ALTER DATABASE [$newName] SET MULTI_USER")
    }
}

function sql-get-dbs {
    _sql-load-module

    $Databases = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("SELECT * from sys.databases")

    return $Databases
}

function sql-get-items {
    Param($dbName, $tableName, $selectFilter, $whereFilter)

    _sql-load-module

    $result = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("
        SELECT $selectFilter
        FROM [${dbName}].[dbo].[${tableName}]
        WHERE $whereFilter")

    return $result
}

function sql-update-items {
    Param($dbName, $tableName, $value, $whereFilter)

    _sql-load-module

    $result = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query "
        UPDATE [${dbName}].[dbo].[${tableName}]
        SET dta='${value}'
        WHERE $whereFilter"

    return $result
}

function sql-insert-items {
    Param($dbName, $tableName, $value, $whereFilter)

    _sql-load-module

    $result = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query "
        UPDATE [${dbName}].[dbo].[${tableName}]
        SET dta='${value}'
        WHERE $whereFilter"

    return $result
}

function sql-delete-items {
    Param($dbName, $tableName, $whereFilter)

    _sql-load-module

    $result = Invoke-SQLcmd -ServerInstance $sqlServerInstance -Query ("
        DELETE FROM [${dbName}].[dbo].[${tableName}]
        WHERE $whereFilter")
}

function sql-test-isDbNameDuplicate {
    Param($dbName)

    _sql-load-module

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