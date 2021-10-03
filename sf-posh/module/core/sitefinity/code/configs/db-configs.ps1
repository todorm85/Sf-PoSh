<#
    .SYNOPSIS
    Extracts the sitefinity config contents from the database, formats it and saves it to desktop by default.
    .PARAMETER configName
    The name of the sitefinity config without extension
    .PARAMETER filePath
    The path to the file where the config contents will be saved. By default:"${Env:userprofile}\Desktop\dbExport.xml" 
    .OUTPUTS
    None
#>
function sf-config-getFromDb {
    
    Param(
        [Parameter(Mandatory = $true)]$configName,
        $dbName,
        $filePath = "${Env:userprofile}\Desktop\dbExport.xml"
    )

    if (!$dbName) {
        $dbName = sf-db-getNameFromDataConfig
    }
    
    # $config = sql-get-items -dbName $dbName -tableName 'sf_xml_config_items' -selectFilter 'dta' -whereFilter "path='${configName}.config'"
    $config = Invoke-SQLcmd -ServerInstance $global:sf.config.sqlServerInstance -Query ("
        SELECT *
        FROM [$dbName].[dbo].[sf_xml_config_items]
        WHERE path = '$configName.config'
        ") -MaxCharLength 500000

    if ($null -ne $config -and $config -ne '') {
        if (!(Test-Path $filePath)) {
            New-Item -ItemType file -Path $filePath
        }

        $config.dta | Out-File $filePath -Force -Encoding utf8
        . $filePath
    }
    else {
        Write-Information 'Config not found in db'
    }
}

<#
    .SYNOPSIS 
    Deletes the given config contents only from the database. Same config in file system is preserved
    .PARAMETER configName
    The sitefinity config name withouth extension
#>
function sf-config-clearInDb {
    
    Param(
        [Parameter(Mandatory = $true)]$configName
    )

    $dbName = db-getNameFromDataConfig
    $table = 'sf_xml_config_items'
    $value = "dta = '<${configName}/>'"
    $where = "path='${configName}.config'"
    
    sql-update-items -dbName $dbName -whereFilter $where -tableName $table -value $value
}

<#
    .SYNOPSIS
    Inserts config content into database. 
    .DESCRIPTION
    Inserts the sitefinity config content from given path to the database.
    .PARAMETER configName
    Name of sitefinity config without extension that will be overriden in database with content from given file on the fs.
    .PARAMETER filePath
    The source file path whose content will be inserted to the databse. Default: $filePath="${Env:userprofile}\Desktop\dbImport.xml"
    .OUTPUTS
    None
#>
function sf-config-setInDb {
    
    Param(
        [Parameter(Mandatory = $true)]$configName,
        $filePath = "${Env:userprofile}\Desktop\dbImport.xml"
    )

    $dbName = db-getNameFromDataConfig
    $table = 'sf_xml_config_items'
    $xmlString = Get-Content $filePath -Raw
    $value = "dta='$xmlString'"
    $where = "path='${configName}.config'"
    
    sql-update-items -dbName $dbName -tableName $table -whereFilter $where -value $value
}

function sf-config-exportAllFromDb {
    param(
        $dbName,
        $server = ".",
        [switch]$mergeInOneFile
    )

    if (!$dbName) {
        $p = sf-PSproject-get
        $dbName = $p.dbName
        if (!$dbName) {
            throw "No db set."
        }
    }

    $baseFilePath = "${Env:userprofile}\Desktop\exported_dbs\$dbName"
    if (!(Test-Path $baseFilePath)) {
        New-Item -Path $baseFilePath -ItemType Directory
    }

    $mergeFilePath = "$baseFilePath\$dbName.xml"
    if ($mergeInOneFile) {
        Remove-Item $mergeFilePath -Force -ErrorAction SilentlyContinue
    }

    $results = Invoke-SQLcmd -ServerInstance $server -Query ("
        SELECT *
        FROM [$dbName].[dbo].[sf_xml_config_items]
        ORDER BY path
        ") -MaxCharLength 500000
    $results | % {
        if ($mergeInOneFile) {
            "<!--  $($_.path) -->`n$($_.dta)`n" | Out-File -FilePath $mergeFilePath -Encoding utf8 -Append
        }
        else {
            $filePath = "$baseFilePath\$($_.path)"
            $currentItem = $_
            try {
                $doc = [xml]$currentItem.dta
                $doc.Save($filePath) > $null
            }
            catch {
                $currentItem.dta | Out-File -FilePath $filePath -Encoding utf8 -Force        
            }
        }
    }
}