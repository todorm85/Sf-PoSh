<#
.SYNOPSIS
Sets a longer description for the current project.
#>
function proj_setDescription {
    $context = proj_getCurrent

    $context.description = $(Read-Host -Prompt "Enter description: ").ToString()

    _saveSelectedProject $context
}

function proj_getDescription {
    $context = proj_getCurrent
    if ($context.description -and $context.description.StartsWith("https://")) {
        $browserPath = $GLOBAL:Sf.Config.browserPath;
        execute-native "& `"$browserPath`" `"$($context.description)`" -noframemerging" -successCodes @(100)
    } else {
        $context.description
    }
}
