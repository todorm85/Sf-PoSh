function get-batchLogsPath {
    "$home\Desktop\sf-dev-log.txt"
}

function sf-start-allProjectsBatch ($scriptBlock) {
    $logsPath = get-batchLogsPath
    $initialProject = _get-selectedProject
    $sitefinities = _sfData-get-allProjects
    foreach ($sitefinity in $sitefinities) {
        [SfProject]$sitefinity = $sitefinity
        set-currentProject $sitefinity
        sf-start-batch $scriptBlock
    }

    set-currentProject $initialProject
}

function sf-start-batch ($scriptBlock) {
    $logsPath = get-batchLogsPath
    $sitefinity = _get-selectedProject
    try {
        & $scriptBlock $sitefinity
    }
    catch {
        $date = [System.DateTime]::Now
        $sfStamp = "ID: $($sitefinity.id), Name: $($sitefinity.containerName) $($sitefinity.displayName)"
        "$date $sfStamp`nError while processing batch script for project with id $($sitefinity.id)`n$_`n----------------------------------------------" | Out-File $logsPath -Append
    }
}