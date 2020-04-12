function _get-toolsConfigDirPath {
    $nginxConfigsDirPath = _getNginxConfigDirPath
    "$nginxConfigsDirPath\sf-dev"
}

function _getNginxConfigDirPath {
    (Get-Item $Global:sf.config.pathToNginxConfig).Directory.FullName
}
