
<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-goto {
    [CmdletBinding()]
    Param(
        [switch]$configs,
        [switch]$logs,
        [switch]$root,
        [switch]$webConfig
    )

    $context = _sf-get-context
    $webAppPath = $context.webAppPath

    if ($configs) {
        cd "${webAppPath}\App_Data\Sitefinity\Configuration"
        ls
    } elseif ($logs) {
        cd "${webAppPath}\App_Data\Sitefinity\Logs"
        ls
    } elseif ($root) {
        cd "${webAppPath}"
        ls
    } elseif ($webConfig) {
        & "${webAppPath}\Web.config"
    }
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
