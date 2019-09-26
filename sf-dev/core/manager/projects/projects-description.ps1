<#
.SYNOPSIS
Sets a longer description for the current project.
#>
function sf-proj-setDescription {
    $context = sf-proj-getCurrent

    $context.description = $(Read-Host -Prompt "Enter description: ").ToString()

    _saveSelectedProject $context
}

function sf-proj-getDescription {
    $context = sf-proj-getCurrent
    if ($context.description -and $context.description.StartsWith("https://")) {
        $browserPath = $GLOBAL:Sf.Config.browserPath;
        execute-native "& `"$browserPath`" `"$($context.description)`" -noframemerging" -successCodes @(100)
    } else {
        $context.description
    }
}
