function sf-db-getNameFromDataConfig {
    [SfProject]$context = sf-project-getCurrent

    _db-getNameFromDataConfig -appPath $context.webAppPath
}

function sf-db-setNameInDataConfig ($newName) {
    $context = sf-project-getCurrent
    
    $dbName = sf-db-getNameFromDataConfig -context $context
    if (-not $dbName) {
        throw "No database configured for sitefinity."
    }

    try {
        $data = New-Object XML
        $dataConfigPath = "$($context.webAppPath)\App_Data\Sitefinity\Configuration\DataConfig.config"
        $data.Load($dataConfigPath) > $null
        $conStrElement = $data.dataConfig.connectionStrings.add
        $newString = $conStrElement.connectionString -replace $dbName, $newName
        $conStrElement.SetAttribute("connectionString", $newString)
        $data.Save($dataConfigPath) > $null
    }
    catch {
        throw "Error setting database name in config file ${dataConfigPath}.`n $_"
    }
}

function _db-getNameFromDataConfig ($appPath) {
    [XML]$data = _getDataConfig $appPath
    if ($data) {
        $conStrs = $data.dataConfig.connectionStrings.add
        $sfConStrEl = $conStrs | Where-Object { $_.name -eq 'Sitefinity' }
        if ($sfConStrEl) {
            $connection = $sfConStrEl.connectionString
            $connection -match "initial catalog='{0,1}(?<dbName>.*?)'{0,1}(;|$)" > $null
            if ($matches) {
                $dbName = $matches['dbName']
                return $dbName
            }
        }
    }    

    return $null
}

function _getDataConfig ([string]$webAppPath) {
    $data = New-Object XML
    $dataConfigPath = "$($webAppPath)\App_Data\Sitefinity\Configuration\DataConfig.config"
    if (Test-Path -Path $dataConfigPath) {
        $data.Load($dataConfigPath) > $null
        return $data
    }

    return $null
}
