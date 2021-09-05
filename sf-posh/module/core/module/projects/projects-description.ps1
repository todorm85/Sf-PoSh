<#
.SYNOPSIS
Sets a longer description for the current project.
#>
function sf-PSproject-setDescription {
    $context = sf-PSproject-get

    $context.description = $(Read-Host -Prompt "Enter description: ").ToString()

    sf-PSproject-save $context
}

function sf-PSproject-getDescription {
    $context = sf-PSproject-get
    if ($context.description -and $context.description.StartsWith("https://")) {
        $browserPath = $GLOBAL:sf.Config.browserPath;
        execute-native "& `"$browserPath`" `"$($context.description)`" -noframemerging" -successCodes @(100)
    } else {
        $context.description
    }
}
