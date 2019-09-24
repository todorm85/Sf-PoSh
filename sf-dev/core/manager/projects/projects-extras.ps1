<#
.SYNOPSIS
Sets a longer description for the current project.
#>
function Set-Description {
    $context = Get-CurrentProject

    $context.description = $(Read-Host -Prompt "Enter description: ").ToString()

    _save-selectedProject $context
}
