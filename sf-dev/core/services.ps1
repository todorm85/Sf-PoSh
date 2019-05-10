function _get-config {
    [Config]$Script:sfDevConfig
}

function _get-sqlClient {
    [Config]$config = _get-config
    [SqlClient]::new($config.sqlUser, $config.sqlPass, $config.sqlServerInstance)
}