Get-Module sf-posh | Remove-Module -Force

if (Get-Module webadministration) {
    Remove-Module WebAdministration -Force
}

Import-Module WebAdministration -Force
Import-Module "$PSScriptRoot\..\..\sf-posh\sf-posh.psm1" -Force -ArgumentList $true

. "$PSScriptRoot\test-util.ps1"
. "$PSScriptRoot\test-project.ps1"