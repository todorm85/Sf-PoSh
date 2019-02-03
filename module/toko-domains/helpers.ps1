
function Get-ListenAddress() {
    function isAddressOccupied($address) {
        # return (((Get-Content $hostsPath) -match ".*$address.*").Count -gt 0)
        return ((netsh interface portproxy show all) -match ".*$address.*") -or ((Get-Content $global:hostsPath) -match ".*$address.*")
    }

    $firstOctet = 1
    while ($firstOctet -lt 255) {
        $address = "127.5.5.$firstOctet"
        if (isAddressOccupied $address) {
            $firstOctet++
        }
        else {
            break;
        }
    }

    if ($firstOctet -eq 255) {
        throw "No free addresses in 127.5.5.0/24 to listen on port 80"
    }
    
    return $address
}
