
function Add-PortProxy ($listenAddress, $connectPort) {
    netsh interface portproxy add v4tov4 listenport=80 listenaddress=$listenAddress connectport=$connectPort connectaddress=127.0.0.1
    if ($GLOBAL:LASTEXITCODE) {
        throw "Error creating portproxy. $_"
    }
}

function Remove-PortProxy ($listenAddress) {
    netsh interface portproxy delete v4tov4 listenport=80 listenaddress=$listenAddress
    if ($GLOBAL:LASTEXITCODE) {
        throw "Error creating portproxy. $_"
    }
}
    