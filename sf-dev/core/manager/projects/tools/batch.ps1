
<#
.SYNOPSIS
Iterates through all projects and passes each project as a parameter to the script block.
.INPUTS
scriptBlock - The script to execute against each project.
#>
function sf-proj-tools-StartAllProjectsBatch ($scriptBlock) {
    $initialProject = sf-proj-getCurrent
    $sitefinities = sf-data-getAllProjects
    $errors = ''
    foreach ($sitefinity in $sitefinities) {
        [SfProject]$sitefinity = $sitefinity
        sf-proj-setCurrent $sitefinity
        try {
            _executeBatchBlock $scriptBlock
        }
        catch {
            $sfStamp = "ID: $($sitefinity.id), Name: $($sitefinity.displayName)"
            $errors = "$errors`n---------------------------------`n$sfStamp`nError while processing script:`n$_`nCommand: $($_.InvocationInfo.MyCommand)`nStack: $($_.Exception.StackTrace)"
        }
    }

    sf-proj-setCurrent $initialProject

    if ($errors) {
        throw $errors
    }
}

function _executeBatchBlock ($scriptBlock) {
    $sitefinity = sf-proj-getCurrent
    & $scriptBlock $sitefinity
}
