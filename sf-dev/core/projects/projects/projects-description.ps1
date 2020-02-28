<#
.SYNOPSIS
Sets a longer description for the current project.
#>
function sf-project-setDescription {
    $context = sf-project-getCurrent

    $context.description = $(Read-Host -Prompt "Enter description: ").ToString()

    _saveSelectedProject $context
}

function sf-project-getDescription {
    $context = sf-project-getCurrent
    if ($context.description -and $context.description.StartsWith("https://")) {
        $browserPath = $GLOBAL:Sf.Config.browserPath;
        execute-native "& `"$browserPath`" `"$($context.description)`" -noframemerging" -successCodes @(100)
    } else {
        $context.description
    }
}
