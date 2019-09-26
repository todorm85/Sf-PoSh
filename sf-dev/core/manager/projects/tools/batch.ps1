
<#
.SYNOPSIS
Iterates through all projects and passes each project as a parameter to the script block.
.INPUTS
scriptBlock - The script to execute against each project.
#>
function proj-tools-startAllProjectsBatch ($scriptBlock) {
    $initialProject = proj-getCurrent
    $sitefinities = data-getAllProjects
    $errors = ''
    foreach ($sitefinity in $sitefinities) {
        [SfProject]$sitefinity = $sitefinity
        proj-setCurrent $sitefinity
        try {
            _executeBatchBlock $scriptBlock
        }
        catch {
            $sfStamp = "ID: $($sitefinity.id), Name: $($sitefinity.displayName)"
            $errors = "$errors`n---------------------------------`n$sfStamp`nError while processing script:`n$_`nCommand: $($_.InvocationInfo.MyCommand)`nStack: $($_.Exception.StackTrace)"
        }
    }

    proj-setCurrent $initialProject

    if ($errors) {
        throw $errors
    }
}

function _executeBatchBlock ($scriptBlock) {
    $sitefinity = proj-getCurrent
    & $scriptBlock $sitefinity
}
