$GLOBAL:Sf = [PSCustomObject]@{}

. "$PSScriptRoot/bootstrap/bootstrap.ps1"

$tokoAdmin.sql.Configure($conf.sqlUser, $conf.sqlPass, $conf.sqlServerInstance)

Export-ModuleMember -Function * -Alias *
