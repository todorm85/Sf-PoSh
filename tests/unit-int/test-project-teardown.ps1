Set-Location $GLOBAL:PSHOME
Remove-Website -Name $Global:testProjectWebsiteName -ErrorAction SilentlyContinue -Confirm:$false
sql-delete-database -dbName "testsDb"
