function _get-toolsConfigDirPath {
    $nginxConfigsDirPath = _getNginxConfigDirPath
    "$nginxConfigsDirPath\sf-posh"
}

function _getNginxConfigDirPath {
    (Get-Item $Global:sf.config.pathToNginxConfig).Directory.FullName
}
