
<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-goto-configs {
    [CmdletBinding()]
    Param()

    $context = _sf-get-context
    $webAppPath = $context.webAppPath

    cd "${webAppPath}\App_Data\Sitefinity\Configuration"
    ls
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-clear-nugetCache {
    [CmdletBinding()]
    Param()
    
    $context = _sf-get-context
    if (!(Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }

    & "$($context.solutionPath)\.nuget\nuget.exe" locals all -clear
}
