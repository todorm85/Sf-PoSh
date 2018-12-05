$Script:hostsPath = "$($env:windir)\system32\Drivers\etc\hosts"

$oldLocation = Get-Location
Set-Location ${PSScriptRoot}
. "$PSScriptRoot\hosts-file.ps1"
. "$PSScriptRoot\port-proxy.ps1"
. "$PSScriptRoot\helpers.ps1"
Set-Location $oldLocation

 <#
 .SYNOPSIS
    Shows all domains mapped to local ports
 #>
function Show-Domains() {
    $hostsFileEntries = Get-Content $Script:hostsPath
    $portProxies = netsh interface portproxy show all
    $hostsFileEntries | ForEach-Object {
        $hostsEntryAddress = $_.Split(' ')[0]
        $hostsEntryDomain = $_.Split(' ')[1]
        $port = ''
        $portProxies | ForEach-Object { 
            if($_ -match "^${hostsEntryAddress}.* (?<port>[0-9]+)$") {
                $port = $Matches.port
            }
        } | Out-Null

        if ($port) {
            "$hostsEntryDomain $port"
        }
    }
}

Set-Alias -Name sdo -Value Show-Domains

<#
.SYNOPSIS
    Maps domain to local port
.EXAMPLE
    PS C:\> Add-Ddomain myDomain.com 1111
    Calls to myDomain.com will be redirected to localhost:1111
.INPUTS
    the domain
    the port
.OUTPUTS
    none
#>
function Add-Domain ($hostname, $mappedLocalPort) {
    $address = Get-ListenAddress
    
    # $duplicates = Show-Domains | where {$_ -match ".*$hostname.*"}
    # if ($duplicates) {
    #     throw "Domain is already mapped."
    # }

    Add-PortProxy -listenAddress $address -connectPort $mappedLocalPort

    try {
        Add-ToHostsFile -address $address -hostname $hostname
    }
    catch {
        Write-Error "Error writing to hosts file. $_"
        Remove-PortProxy $address
    }
}

Set-Alias -Name ado -Value Add-Domain

<#
.SYNOPSIS
    Removes a domain if mapped to local port
.EXAMPLE
    PS C:\> Remove-Ddomain myDomain.com
    Removes the mapping of myDomain.com to the local port it has been mapped if any.
.INPUTS
    the domain
.OUTPUTS
    none or throws if domain is not mapped to local port
#>
function Remove-Domain ($domain) {
    $address = Remove-FromHostsFile $domain
    try {
        Remove-PortProxy $address
    }
    catch {
        Write-Error "Error: $_`nError removing port proxy for $address. Try issuing manually `"netsh interface portproxy delete v4tov4 listenport= listenaddress=`"."
    }
}

Set-Alias -Name rdo -Value Remove-Domain

Export-ModuleMember -Function * -Alias *
