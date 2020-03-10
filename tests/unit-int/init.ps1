. "${PSScriptRoot}\..\utils\test-util.ps1"

Get-Website | ? Name -NotLike "sft*" | Remove-Website -Confirm:$false