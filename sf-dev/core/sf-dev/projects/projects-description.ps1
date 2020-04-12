<#
.SYNOPSIS
Sets a longer description for the current project.
#>
function sd-project-setDescription {
    $context = sd-project-getCurrent

    $context.description = $(Read-Host -Prompt "Enter description: ").ToString()

    sd-project-save $context
}

function sd-project-getDescription {
    $context = sd-project-getCurrent
    if ($context.description -and $context.description.StartsWith("https://")) {
        $browserPath = $GLOBAL:sf.Config.browserPath;
        execute-native "& `"$browserPath`" `"$($context.description)`" -noframemerging" -successCodes @(100)
    } else {
        $context.description
    }
}
