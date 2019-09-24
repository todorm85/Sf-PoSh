$GLOBAL:Sf = [PSCustomObject]@{}

. "$PSScriptRoot/bootstrap/bootstrap.ps1"

$tokoAdmin.sql.Configure($GLOBAL:Sf.Config.sqlUser, $GLOBAL:Sf.Config.sqlPass, $GLOBAL:Sf.Config.sqlServerInstance)

Export-ModuleMember -Function * -Alias *
