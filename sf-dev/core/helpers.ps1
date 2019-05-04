function _get-config {
    [Config]$Script:config
}

function _get-sqlClient {
    [Config]$config = _get-config
    [SqlClient]$client = get-sqlClient -user $config.sqlUser -pass $config.sqlPass -server $config.sqlServerInstance
    $client
}
