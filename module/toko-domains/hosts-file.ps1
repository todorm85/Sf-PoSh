
function Add-ToHostsFile ($address, $hostname) {
    If ((Get-Content $hostsPath) -notcontains "$address $hostname") {
        Add-Content -Encoding utf8 $hostsPath "$address $hostname" -ErrorAction Stop
    }
}

function Remove-FromHostsFile ($hostname) {
    (Get-Content $hostsPath) | ForEach-Object {
        $found = $_ -match "^(?<address>.*?) $hostname$"
        if ($found) {
            $address = $Matches.address
        }
    } | Out-Null

    if (-not $address) {
        throw 'Domain not found in hosts file.'
    }

    (Get-Content $Script:hostsPath) |
        Where-Object { $_ -notmatch ".*? $hostname$" } |
        Out-File $Script:hostsPath -Force -Encoding utf8 -ErrorAction Stop

    return $address
}
