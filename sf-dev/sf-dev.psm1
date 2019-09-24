. "$PSScriptRoot/bootstrap/bootstrap.ps1"
[Config]$conf = $GLOBAL:SfDevConfig
$tokoAdmin.sql.Configure($conf.sqlUser, $conf.sqlPass, $conf.sqlServerInstance)
Export-ModuleMember -Function * -Alias *
