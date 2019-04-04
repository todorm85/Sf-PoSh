<#
    .SYNOPSIS 
    Renames the current selected sitefinity.
    .PARAMETER markUnused
    If set renames the instanse to '-' and the workspace name to 'unused_{current date}.
    .OUTPUTS
    None
#>
function sf-set-description {
    $context = _get-selectedProject

    $context.description = $(Read-Host -Prompt "Enter description: ").ToString()

    _save-selectedProject $context
}
