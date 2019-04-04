function sf-get-appDbName ([SfProject]$context) {
    if (-not $context) {
        [SfProject]$context = _get-selectedProject
    }

    $data = New-Object XML
    $dataConfigPath = "$($context.webAppPath)\App_Data\Sitefinity\Configuration\DataConfig.config"
    if (Test-Path -Path $dataConfigPath) {
        $data.Load($dataConfigPath) > $null
        $conStr = $data.dataConfig.connectionStrings.add.connectionString
        $conStr -match "initial catalog='{0,1}(?<dbName>.*?)'{0,1}(;|$)" > $null
        $dbName = $matches['dbName']
        return $dbName
    }
    else {
        return $context.id
    }
}

function sf-set-appDbName ($newName) {
    $context = _get-selectedProject
    $dbName = sf-get-appDbName
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
