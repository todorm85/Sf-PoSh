function _nginx-getToolsConfigDirPath {
    $nginxConfigsDirPath = _nginx-getConfigDirPath
    "$nginxConfigsDirPath\sf-posh"
}

function _nginx-getConfigDirPath {
    (Get-Item $Global:sf.config.pathToNginxConfig).Directory.FullName
}
