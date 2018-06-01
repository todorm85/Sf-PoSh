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

    $context = _get-selectedProject
    $webAppPath = $context.webAppPath

    if ($configs) {
        cd "${webAppPath}\App_Data\Sitefinity\Configuration"
        ls
    }
    elseif ($logs) {
        cd "${webAppPath}\App_Data\Sitefinity\Logs"
        ls
    }
    elseif ($root) {
        cd "${webAppPath}"
        ls
    }
    elseif ($webConfig) {
        & "${webAppPath}\Web.config"
    }
}
