function _iis-load-webAdministrationModule () {
    $mod = Get-Module WebAdministration
    if ($null -eq $mod -or '' -eq $mod) {
        Import-Module WebAdministration
    }
}

function iis-get-websitePort {
    Param (
        [string]$webAppName
    )
    if (-not ($webAppName)) {
        return ""
    }

    _iis-load-webAdministrationModule
    Get-WebBinding -Name $webAppName | Select-Object -expand bindingInformation | ForEach-Object {$_.split(':')[-2]}
}

function iis-show-appPoolPid {

    & "C:\Windows\System32\inetsrv\appcmd.exe" list wps
}

function iis-get-usedPorts {

    _iis-load-webAdministrationModule
    Get-WebBinding | Select-Object -expand bindingInformation | ForEach-Object {$_.split(':')[-2]}
}

function iis-get-appPoolApps ($appPoolName) {
    _iis-load-webAdministrationModule
    $sites = get-webconfigurationproperty "/system.applicationHost/sites/site/application[@applicationPool=`'$appPoolName`'and @path='/']/parent::*" machine/webroot/apphost -name name
    $apps = get-webconfigurationproperty "/system.applicationHost/sites/site/application[@applicationPool=`'$appPoolName`'and @path!='/']" machine/webroot/apphost -name path
    $arr = @()
    if ($null -ne $sites) {$arr += $sites}
    if ($null -ne $apps) {$arr += $apps}
    return $arr
}

function iis-create-appPool {
    Param(
        [Parameter(Mandatory = $true)][string]$appPool,
        [Parameter(Mandatory = $true)][string]$windowsUserPassword
    )
    # CreateAppPool
    New-Item ("IIS:\AppPools\${appPool}") | Set-ItemProperty -Name "managedRuntimeVersion" -Value "v4.0"
    $userName = [Environment]::UserName
    Set-ItemProperty ("IIS:\AppPools\${appPool}") -Name "processModel" -value @{userName = "progress\${userName}"; password = $windowsUserPassword; identitytype = 3}
}

function iis-get-appPools {
    
    @(Get-ChildItem ("IIS:\AppPools"))
}

function iis-delete-appPool ($appPoolName) {
    # display app pools with websites
    _iis-load-webAdministrationModule
    if ($appPoolName -eq '' -or $null -eq $appPoolName) {
        $appPools = @(Get-ChildItem ("IIS:\AppPools"))
        $appPools

        foreach ($pool in $appPools) {
            $index = [array]::IndexOf($appPools, $pool)
            Write-Host "$index : $($pool.name)"
        }

        while ($true) {
            [int]$choice = Read-Host -Prompt 'Choose appPool'
            $selectedPool = $appPools[$choice]
            if ($null -ne $selectedPool) {
                break;
            }
        }

        $appPoolName = $selectedPool.name
    }
    
    $apps = iis-get-appPoolApps $appPoolName
    if ($apps.Length -gt 0) {
        Write-Host 'CANNOT DELETE APP POOL! AppPool has websites and apps hosted'
    }
    else {
        Remove-WebAppPool -Name $appPoolName
    }
}

function iis-create-website {
    Param(
        [Parameter(Mandatory = $true)][string]$newWebsiteName,
        [Parameter(Mandatory = $true)][string]$newPort,
        [Parameter(Mandatory = $true)][string]$newAppPath,
        [Parameter(Mandatory = $true)][string]$newAppPool
    )

    _iis-load-webAdministrationModule
    
    $isReserved = $false
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
        New-Item $poolPath
        Set-ItemProperty $poolPath -Name "processModel.idleTimeout" -Value ([TimeSpan]::FromMinutes(0))
    }

    # create website
    New-Item ("iis:\Sites\${newWebsiteName}") -bindings @{protocol = "http"; bindingInformation = ("*:${newPort}:")} -physicalPath $newAppPath | Set-ItemProperty -Name "applicationPool" -Value $newAppPool

    $Acl = Get-Acl $newAppPath
    $Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("IIS AppPool\$newAppPool", "Full", "ContainerInherit,ObjectInherit", "None", "Allow")
    $Acl.SetAccessRule($Ar)
    Set-Acl $newAppPath $Acl

    return @{name = $newWebsiteName; port = $newPort; appPool = $newAppPool; appPath = $newAppPath}
}

function iis-get-siteAppPool {
    Param(
        [string]$websiteName
    )
    
    if (-not ($websiteName)) {
        return ""
    }

    _iis-load-webAdministrationModule
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

function iis-add-sitePort {
    Param(
        $name, $port
    )

    _iis-load-webAdministrationModule
    New-WebBinding -Name $websiteName -port $port
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

function iis-rename-website {
    Param(
        [string]$name,
        [string]$newName
    )
    
    Rename-Item "IIS:\Sites\$name" "$newName"
}

function iis-new-subApp {
    Param(
        [string]$siteName,
        [string]$appName,
        [string]$path
    )

    _iis-load-webAdministrationModule
    New-Item "IIS:\Sites\$($siteName)\${appName}" -physicalPath $path -type "Application"
}

function iis-remove-subApp {
    Param(
        [string]$siteName,
        [string]$appName
    )

    if ([String]::IsNullOrEmpty($appName) -or [string]::IsNullOrWhiteSpace($appName)) {
        throw "Invalid app name"
    }

    _iis-load-webAdministrationModule
    Remove-Item "IIS:\Sites\$($siteName)\${appName}" -force -recurse -Confirm:$false
}

function iis-set-sitePath {
    Param(
        [string]$siteName,
        [string]$path
    )

    _iis-load-webAdministrationModule
    Get-Item ("iis:\Sites\$($siteName)") | Set-ItemProperty -Name "physicalPath" -Value $path
}