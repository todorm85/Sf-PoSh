<#
.SYNOPSIS
Sets a longer description for the current project.
#>
function sf-set-description {
    $context = sf-get-currentProject

    $context.description = $(Read-Host -Prompt "Enter description: ").ToString()

    _save-selectedProject $context
}
