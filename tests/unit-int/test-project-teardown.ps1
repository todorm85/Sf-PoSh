Set-Location $GLOBAL:PSHOME
Remove-Website -Name $Global:testProject.websiteName -ErrorAction SilentlyContinue -Confirm:$false
sql-delete-database -dbName "testsDb"
