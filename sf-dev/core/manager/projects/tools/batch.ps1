
<#
.SYNOPSIS
Iterates through all projects and passes each project as a parameter to the script block.
.INPUTS
scriptBlock - The script to execute against each project.
#>
function proj_tools_startAllProjectsBatch ($scriptBlock) {
    $initialProject = proj_getCurrent
    $sitefinities = data_getAllProjects
    $errors = ''
    foreach ($sitefinity in $sitefinities) {
        [SfProject]$sitefinity = $sitefinity
        proj_setCurrent $sitefinity
        try {
            _executeBatchBlock $scriptBlock
        }
        catch {
            $sfStamp = "ID: $($sitefinity.id), Name: $($sitefinity.displayName)"
            $errors = "$errors`n---------------------------------`n$sfStamp`nError while processing script:`n$_`nCommand: $($_.InvocationInfo.MyCommand)`nStack: $($_.Exception.StackTrace)"
        }
    }

    proj_setCurrent $initialProject

    if ($errors) {
        throw $errors
    }
}

function _executeBatchBlock ($scriptBlock) {
    $sitefinity = proj_getCurrent
    & $scriptBlock $sitefinity
}
