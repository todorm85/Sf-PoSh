param(
    [parameter(Position=0,Mandatory=$false)][string]$customConfigPath=$null
)
$global:customConfigPath = $customConfigPath
$global:moduleUserDir = "$home\documents\sf-dev"
if (-not (Test-Path $global:moduleUserDir)) {
    New-Item -Path $global:moduleUserDir -ItemType Directory
}

Set-Location ${PSScriptRoot}

. "./bootstrap/bootstrap.ps1"

Export-ModuleMember -Function * -Alias *
