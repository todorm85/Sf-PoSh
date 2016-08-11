Param (
        [Parameter(Mandatory=$true)][string] $ServerInstance
    )

function sql-delete-database {
    Param (
            [Parameter(Mandatory=$true)][string] $dbName
        )

    Import-Module SQLPS -DisableNameChecking

    $Databases = Invoke-SQLcmd -ServerInstance $ServerInstance -Query ("SELECT * from sys.databases where NAME = '$dbName'")

    ForEach ($Database in $Databases)
    { 
        Invoke-SQLcmd -ServerInstance $ServerInstance -Query (
            "alter database [" + $Database.Name + "] set single_user with rollback immediate
            DROP DATABASE [" + $Database.Name + "]")
    }
}

function sql-get-dbs {
    
    Import-Module SQLPS -DisableNameChecking

    $Databases = Invoke-SQLcmd -ServerInstance $ServerInstance -Query ("SELECT * from sys.databases")

    return $Databases
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