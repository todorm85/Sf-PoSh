function sf-set-description {
    $context = _get-selectedProject

    $context.description = $(Read-Host -Prompt "Enter description: ").ToString()

    _save-selectedProject $context
}
