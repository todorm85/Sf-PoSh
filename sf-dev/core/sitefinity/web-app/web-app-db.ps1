function sf-get-appDbName ([SfProject]$context) {
    if (-not $context) {
        [SfProject]$context = _get-selectedProject
    }

    $dbName = get-currentAppDbName -project $context
    if ($dbName) {
        return $dbName
    }
    else {
        return $context.id
    }
}

function get-currentAppDbName ([SfProject]$project) {
    if (-not $project) {
        [SfProject]$project = _get-selectedProject
    }

    $data = New-Object XML
    $dataConfigPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration\DataConfig.config"
    if (Test-Path -Path $dataConfigPath) {
        $data.Load($dataConfigPath) > $null
        $conStr = $data.dataConfig.connectionStrings.add.connectionString
        $conStr -match "initial catalog='{0,1}(?<dbName>.*?)'{0,1}(;|$)" > $null
        if ($matches) {
            $dbName = $matches['dbName']
            return $dbName
        }
    }

    return $null
}

function sf-set-appDbName ($newName, [SfProject]$context) {
    if (!$context) {
        $context = _get-selectedProject
    }
    
    $dbName = sf-get-appDbName -context $context
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
