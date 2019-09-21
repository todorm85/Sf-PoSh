. "$PSScriptRoot/bootstrap/bootstrap.ps1"
[Config]$conf = _get-config
$tokoAdmin.sql.Configure($conf.sqlUser, $conf.sqlPass, $conf.sqlServerInstance)
Export-ModuleMember -Function * -Alias *
