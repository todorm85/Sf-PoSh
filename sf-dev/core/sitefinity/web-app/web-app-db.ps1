function sf-app-db-getName {
    [SfProject]$context = sf-proj-getCurrent

    _sf-app-db-getName -appPath $context.webAppPath
}

function sf-app-db-setName ($newName) {
    $context = sf-proj-getCurrent
    
    $dbName = sf-app-db-getName -context $context
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

function _sf-app-db-getName ($appPath) {
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
