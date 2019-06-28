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
    
    [XML]$data = _get-dataConfig $project
    if ($data) {
        $conStrs = $data.dataConfig.connectionStrings.add
        $sfConStrEl = $conStrs | where { $_.name -eq 'Sitefinity' }
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

function _get-dataConfig ([SfProject]$project) {
    $data = New-Object XML
    $dataConfigPath = "$($project.webAppPath)\App_Data\Sitefinity\Configuration\DataConfig.config"
    if (Test-Path -Path $dataConfigPath) {
        $data.Load($dataConfigPath) > $null
        return $data
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
