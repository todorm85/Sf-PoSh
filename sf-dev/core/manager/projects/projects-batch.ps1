<#
.SYNOPSIS
Iterates through all projects and passes each project as a parameter to the script block.
.INPUTS
scriptBlock - The script to execute against each project.
#>
function Start-AllProjectsBatch ($scriptBlock) {
    $initialProject = Get-CurrentProject
    $sitefinities = Get-AllProjects
    $errors = ''
    foreach ($sitefinity in $sitefinities) {
        [SfProject]$sitefinity = $sitefinity
        set-currentProject_ $sitefinity
        try {
            execute-batchBlock_ $scriptBlock
        }
        catch {
            $sfStamp = "ID: $($sitefinity.id), Name: $($sitefinity.displayName)"
            $errors = "$errors`n---------------------------------`n$sfStamp`nError while processing script:`n$_`nCommand: $($_.InvocationInfo.MyCommand)`nStack: $($_.Exception.StackTrace)"
        }
    }

    set-currentProject_ $initialProject

    if ($errors) {
        throw $errors
    }
}

function execute-batchBlock_ ($scriptBlock) {
    $sitefinity = Get-CurrentProject
    & $scriptBlock $sitefinity
}
