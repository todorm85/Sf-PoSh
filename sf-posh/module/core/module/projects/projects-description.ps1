<#
.SYNOPSIS
Sets a longer description for the current project.
#>
function sf-project-setDescription {
    $context = sf-project-get

    $context.description = $(Read-Host -Prompt "Enter description: ").ToString()

    sf-project-save $context
}

function sf-project-getDescription {
    $context = sf-project-get
    if ($context.description -and $context.description.StartsWith("https://")) {
        $browserPath = $GLOBAL:sf.Config.browserPath;
        execute-native "& `"$browserPath`" `"$($context.description)`" -noframemerging" -successCodes @(100)
    } else {
        $context.description
    }
}
