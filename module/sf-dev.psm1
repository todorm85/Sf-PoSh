param(
    [parameter(Position=0,Mandatory=$false)][string]$customConfigPath=$null
)
$global:customConfigPath = $customConfigPath
Set-Location ${PSScriptRoot}

. "./bootstrap/bootstrap.ps1"

Export-ModuleMember -Function * -Alias *
