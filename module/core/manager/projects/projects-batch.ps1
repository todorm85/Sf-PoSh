function sf-start-allProjectsBatch ($scriptBlock) {
    $initialProject = _get-selectedProject
    $sitefinities = _sfData-get-allProjects
    $errors = ''
    foreach ($sitefinity in $sitefinities) {
        [SfProject]$sitefinity = $sitefinity
        set-currentProject $sitefinity
        try {
            sf-start-batch $scriptBlock
        }
        catch {
            $sfStamp = "ID: $($sitefinity.id), Name: $($sitefinity.containerName) $($sitefinity.displayName)"
            $errors = "$errors`n---------------------------------`n$sfStamp`nError while processing script:`n$_"
        }
    }

    set-currentProject $initialProject

    if ($errors) {
        throw $errors
    }
}

function sf-start-batch ($scriptBlock) {
    $sitefinity = _get-selectedProject
    & $scriptBlock $sitefinity
}