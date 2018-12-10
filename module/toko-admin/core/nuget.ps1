<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function clear-nugetCache {
    execute-native "& `"$($PSScriptRoot)\..\external-tools\nuget.exe`" locals all -clear"
}
