function iis-get-websitePort {
    Param (
        [string]$webAppName
    )
    if (-not ($webAppName)) {
        return ""
    }

    (iis-get-binding $webAppName).port
}

function iis-get-usedPorts {

    Get-WebBinding | Select-Object -expand bindingInformation | ForEach-Object {$_.split(':')[-2]}
}

function iis-create-website {
    Param(
        [Parameter(Mandatory = $true)][string]$newWebsiteName,
        [string]$domain = '',
        [Parameter(Mandatory = $true)][string]$newPort,
        [Parameter(Mandatory = $true)][string]$newAppPath,
        [Parameter(Mandatory = $true)][string]$newAppPool
    )

    
    ForEach ($reservedPort in $reservedPorts) {
        if ($reservedPort -eq $newPort) {
            throw "Port ${newPort} already used"
        }
    }

    $availablePools = @(Get-ChildItem -Path "IIS:\AppPools")
    $found = $false
    ForEach ($pool in $availablePools) {
        if ($pool.name.ToLower() -eq $newAppPool) {
            $found = $true
            break;
        }
    }

    if (-not $found) {
        $poolPath = "IIS:\AppPools\$newAppPool"
        New-Item $poolPath > $null
        Set-ItemProperty $poolPath -Name "processModel.idleTimeout" -Value ([TimeSpan]::FromMinutes(0))
    }

    # create website
    New-Item ("iis:\Sites\${newWebsiteName}") -bindings @{protocol = "http"; bindingInformation = "*:${newPort}:"} -physicalPath $newAppPath | Set-ItemProperty -Name "applicationPool" -Value $newAppPool > $null
    if ($domain) {
        iis-set-binding -siteName $newWebsiteName -domainName $domain -port $newPort
    }

    $Acl = Get-Acl $newAppPath
    $Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("IIS AppPool\$newAppPool", "Full", "ContainerInherit,ObjectInherit", "None", "Allow")
    $Acl.SetAccessRule($Ar)
    Set-Acl $newAppPath $Acl
    $res = @{name = $newWebsiteName; port = $newPort; appPool = $newAppPool; appPath = $newAppPath}
    return $res
}

function iis-get-siteAppPool {
    Param(
        [string]$websiteName
    )
    
    if (-not ($websiteName)) {
        return ""
    }

    Get-ItemProperty "IIS:\Sites\${websiteName}" -Name "applicationPool"
}

function iis-test-isPortFree {
    Param($port)

    $usedPorts = iis-get-usedPorts
    $isFree = $true
    ForEach ($usedPort in $usedPorts) {
        if ($usedPort -eq $port) {
            $isFree = $false
            break
        }
    }

    return $isFree
}

function iis-test-isSiteNameDuplicate {
    Param(
        [string]$name
    )

    $availableSites = @(Get-ChildItem -Path "IIS:\Sites")
    $isDuplicateSite = $false
    ForEach ($site in $availableSites) {
        if ($site.name.ToLower() -eq $name.ToLower()) {
            $isDuplicateSite = $true
            break
        }
    }

    return $isDuplicateSite
}

function iis-get-subAppName {
    Param(
        [string]$websiteName
    )

    $appNames = Get-Item "iis:\Sites\$websiteName\*" | Where-Object { $_.GetType().Name -eq "ConfigurationElement" } | ForEach-Object { $_.Name }
    return @($appNames)[0]
}

function iis-new-subApp {
    Param(
        [string]$siteName,
        [string]$appName,
        [string]$path
    )

    
    New-Item "IIS:\Sites\$($siteName)\${appName}" -physicalPath $path -type "Application" > $null
    
    $pool = iis-get-siteAppPool -websiteName $siteName
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

function iis-set-binding {
    param (
        $siteName,
        $domainName,
        $port
    )
    
    Get-WebBinding $siteName | Remove-WebBinding
    New-WebBinding -Name $siteName -Protocol http -Port $port
    if ($domainName) {
        New-WebBinding -Name $siteName -Protocol http -Port $port -HostHeader $domainName        
    }
}

function iis-get-binding {
    param (
        $siteName
    )
    
    $bindings = @(Get-WebBinding -Name $siteName)
    if ($bindings.Count -eq 0) {
        return @{port = $null; domain = $null}
    }
    
    # first binding is to localhost, second to domain if set, port is same for all
    $binding = $bindings[0]
    if ($bindings[1]) {
        $binding = $bindings[1]
    }

    $bindingInfo = $binding.bindingInformation
    $port = $bindingInfo.Split(':')[1]
    $domain = $bindingInfo.Split(':')[2]
    return @{port = $port; domain = $domain; }
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