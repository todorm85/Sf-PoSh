function iis-website-create {
    Param(
        [Parameter(Mandatory = $true)][string]$newWebsiteName,
        [string]$domain = '',
        [string]$newPort,
        [Parameter(Mandatory = $true)][string]$newAppPath,
        [Parameter(Mandatory = $true)][string]$newAppPool
    )

    $poolPath = "IIS:\AppPools\$newAppPool"
    New-Item $poolPath > $null
    Set-ItemProperty $poolPath -Name "processModel.idleTimeout" -Value ([TimeSpan]::FromMinutes(0))

    # create website
    if (!$newPort) { $newPort = iis-getFreePort }
    New-Item ("iis:\Sites\$newWebsiteName") -bindings @{protocol = "http"; bindingInformation = "*:$($newPort):" } -physicalPath $newAppPath | Set-ItemProperty -Name "applicationPool" -Value $newAppPool > $null
    if ($domain) {
        New-WebBinding -Name $newWebsiteName -Protocol http -Port $newPort -HostHeader $domain
    }

    $Acl = Get-Acl $newAppPath
    $Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("IIS AppPool\$newAppPool", "Full", "ContainerInherit,ObjectInherit", "None", "Allow")
    $Acl.SetAccessRule($Ar)
    Set-Acl $newAppPath $Acl
    $res = @{name = $newWebsiteName; port = $newPort; appPool = $newAppPool; appPath = $newAppPath }
    return $res
}

function iis-isPortFree {
    Param($port)
    $matchedPorts = @(Get-WebBinding | Select-Object -expand bindingInformation | ForEach-Object { $_.split(':')[1] } | ? { $_ -eq $port } )
    $matchedPorts.Count -eq 0
}

function iis-new-subApp {
    Param(
        [string]$siteName,
        [string]$appName,
        [string]$path
    )

    New-Item "IIS:\Sites\$($siteName)\${appName}" -physicalPath $path -type "Application" > $null

    $pool = (Get-Website -Name $siteName).applicationPool
    Set-ItemProperty -Path "IIS:\Sites\$($siteName)\${appName}" -Name "applicationPool" -Value $pool > $null
}

function iis-remove-subApp {
    Param(
        [string]$siteName,
        [string]$appName
    )

    if ([String]::IsNullOrEmpty($appName) -or [string]::IsNullOrWhiteSpace($appName)) {
        throw "Invalid app name"
    }

    Remove-Item "IIS:\Sites\$($siteName)\${appName}" -force -recurse -Confirm:$false
}

function iis-set-sitePath {
    Param(
        [string]$siteName,
        [string]$path
    )

    Get-Item ("iis:\Sites\$($siteName)") | Set-ItemProperty -Name "physicalPath" -Value $path
}

function iis-bindings-getAll {
    [OutputType([SiteBinding[]])]
    Param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]$siteName
    )

    $bindings = @(Get-WebBinding -Name $siteName)
    $bindings | ForEach-Object {
        $bindingInfo = $_.bindingInformation
        $protocol = $_.protocol
        $port = $bindingInfo.Split(':')[1]
        $domain = $bindingInfo.Split(':')[2]
        [SiteBinding]@{ port = $port; domain = $domain; protocol = $protocol }
    }
}

function iis-find-site {
    Param(
        [string]$physicalPath
    )

    $availableSites = @(Get-ChildItem -Path "IIS:\Sites")
    ForEach ($site in $availableSites) {
        if ($site.physicalPath.ToLower() -eq $physicalPath.ToLower()) {
            return $site.name
        }
    }

    Get-WebApplication | ForEach-Object {
        if ($_.PhysicalPath.ToLower() -eq $physicalPath.ToLower()) {
            $parent = $_.GetParentElement()
            return $parent.GetAttribute('name').Value
        }
    }
}

function iis-getFreePort {
    param(
        $start
    )

    if (!$start) {
        $start = Get-Random -Minimum 49152 -Maximum 65535
    }
    
    while (!(os-test-isPortFree $start) -or !(iis-isPortFree $start)) {
        $start++
    }

    return $start
}

function iis-site-isStarted {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$name
    )
    
    (Get-WebsiteState -Name $name).Value -eq "Started"
}