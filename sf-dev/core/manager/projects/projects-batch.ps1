<#
.SYNOPSIS
Iterates through all projects and passes each project as a parameter to the script block.
.INPUTS
scriptBlock - The script to execute against each project.
#>
function sf-start-allProjectsBatch ($scriptBlock) {
    $initialProject = sf-get-currentProject
    $sitefinities = sf-get-allProjects
    $errors = ''
    foreach ($sitefinity in $sitefinities) {
        [SfProject]$sitefinity = $sitefinity
        set-currentProject $sitefinity
        try {
            _execute-batchBlock $scriptBlock
        }
        catch {
            $sfStamp = "ID: $($sitefinity.id), Name: $($sitefinity.displayName)"
            $errors = "$errors`n---------------------------------`n$sfStamp`nError while processing script:`n$_`nCommand: $($_.InvocationInfo.MyCommand)`nStack: $($_.Exception.StackTrace)"
        }
    }

    set-currentProject $initialProject

    if ($errors) {
        throw $errors
    }
}

function _execute-batchBlock ($scriptBlock) {
    $sitefinity = sf-get-currentProject
    & $scriptBlock $sitefinity
}
