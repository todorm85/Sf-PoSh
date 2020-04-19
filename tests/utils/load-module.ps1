Get-Module sf-posh | Remove-Module -Force
Import-Module "$PSScriptRoot\..\..\sf-posh\sf-posh.psm1" -Force

. "$PSScriptRoot\test-util.ps1"
. "$PSScriptRoot\test-project.ps1"