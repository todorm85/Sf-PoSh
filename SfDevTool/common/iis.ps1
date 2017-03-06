
function _iis-load-webAdministrationModule () {
    $mod = Get-Module WebAdministration
    if ($null -eq $mod -or '' -eq $mod) {
        Import-Module WebAdministration
    }
}

function iis-get-websitePort {
    Param (
        [Parameter(Mandatory=$true)][string] $webAppName
        )

    _iis-load-webAdministrationModule
    Get-WebBinding -Name $webAppName | select -expand bindingInformation | %{$_.split(':')[-2]}
}

function iis-show-appPoolPid {

    & "C:\Windows\System32\inetsrv\appcmd.exe" list wps
}

function iis-get-usedPorts {

    _iis-load-webAdministrationModule
    Get-WebBinding | select -expand bindingInformation | %{$_.split(':')[-2]}
}

function iis-get-appPoolApps ($appPoolName) {
    _iis-load-webAdministrationModule
    $sites = get-webconfigurationproperty "/system.applicationHost/sites/site/application[@applicationPool=`'$appPoolName`'and @path='/']/parent::*" machine/webroot/apphost -name name
    $apps = get-webconfigurationproperty "/system.applicationHost/sites/site/application[@applicationPool=`'$appPoolName`'and @path!='/']" machine/webroot/apphost -name path
    $arr = @()
    if ($sites -ne $null) {$arr += $sites}
    if ($apps -ne $null) {$arr += $apps}
    return $arr
}

function iis-create-appPool {
    Param(
        [Parameter(Mandatory=$true)][string]$appPool,
        [Parameter(Mandatory=$true)][string]$windowsUserPassword
        )
    # CreateAppPool
    New-Item ("IIS:\AppPools\${appPool}") | Set-ItemProperty -Name "managedRuntimeVersion" -Value "v4.0"
    $userName = [Environment]::UserName
    Set-ItemProperty ("IIS:\AppPools\${appPool}") -Name "processModel" -value @{userName="progress\${userName}";password=$windowsUserPassword;identitytype=3}
}

function iis-get-appPools {
    
    @(Get-ChildItem ("IIS:\AppPools"))
}

function iis-delete-appPool ($appPoolName) {
    # display app pools with websites
    _iis-load-webAdministrationModule
    if ($appPoolName -eq '' -or $appPoolName -eq $null) {
        $appPools = @(Get-ChildItem ("IIS:\AppPools"))
        $appPools

        foreach ($pool in $appPools) {
            $index = [array]::IndexOf($appPools, $pool)
            Write-Host  $index : $pool.name
        }

        while ($true) {
            [int]$choice = Read-Host -Prompt 'Choose appPool'
            $selectedPool = $appPools[$choice]
            if ($selectedPool -ne $null) {
                break;
            }
        }

        $appPoolName = $selectedPool.name
    }
    
    $apps = iis-get-appPoolApps $appPoolName
    if ($apps.Length -gt 0) {
        Write-Host 'CANNOT DELETE APP POOL! AppPool has websites and apps hosted'
    } else {
        Remove-WebAppPool -Name $appPoolName
    }
}

function iis-create-website {
    Param(
        [string]$newWebsiteName,
        [string]$newPort,
        [string]$newAppPath,
        [string]$newAppPool
        )

    _iis-load-webAdministrationModule
    function select-appPool {
        $availablePools = @(Get-ChildItem -Path "IIS:\AppPools")

        # select appPool
        ForEach ($pool in $availablePools) {
            $index = [array]::IndexOf($availablePools, $pool)
            Write-Host $index : $pool.Name
        }

        while ($true) {
            [Int32]$selected = Read-Host -Prompt 'Select appPool: '
            $selectedPool = $availablePools[$selected]
            if ($selectedPool -ne $null) {
                break
            }
        }

        return $selectedPool.name
    }

    if ($newWebsiteName -eq '') {
        $newWebsiteName = Read-Host -Prompt "Enter site name"
    }

    if ($newPort -eq '') {
        $newPort = Read-Host -Prompt 'Enter localhost port on which app will be hosted in IIS'
    }

    # select website port
    $reservedPorts = iis-get-usedPorts
    while ($true) {
        $isReserved = $false
        ForEach ($reservedPort in $reservedPorts) {
            if ($reservedPort -eq $newPort) {
                Write-Host "Port ${newPort} already used"
                $isReserved = $true
                break
            }
        }

        if (!$isReserved) {
            break;
        }

        $newPort = Read-Host -Prompt 'Enter localhost port on which app will be hosted in IIS'
    }

    #select app pool
    $availablePools = @(Get-ChildItem -Path "IIS:\AppPools")
    if ($newAppPool -eq '') {
        $newAppPool = select-appPool
    }

    while ($true) {
        $found = $false
        ForEach ($pool in $availablePools) {
            if ($pool.name.ToLower() -eq $newAppPool) {
                $found = $true
                break;
            }
        }

        if ($found) {
            break;
        }

        $newAppPool = select-appPool
    }

    # select app path
    if ($newAppPath -eq '') {
        $newAppPath = Read-Host -Prompt "Enter app physical path: "
    }

    # create website
    New-Item ("iis:\Sites\${newWebsiteName}") -bindings @{protocol="http";bindingInformation=("*:${newPort}:")} -physicalPath $newAppPath | Set-ItemProperty -Name "applicationPool" -Value $newAppPool

    return @{name = $newWebsiteName; port = $newPort; appPool = $newAppPool; appPath = $newAppPath}
}

function iis-get-siteAppPool {
    Param(
        [Parameter(Mandatory=$true)][string]$websiteName
        )

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
        if ($site.name.ToLower() -eq $name) {
            Write-Host "Site exists"
            $isDuplicateSite = $true
            break
        }
    }

    return $isDuplicateSite
}

function iis-get-subAppName {
    $context = _sf-get-context
    $appNames = Get-Item "iis:\Sites\$($context.websiteName)\*" | where { $_.GetType().Name -eq "ConfigurationElement" } | foreach { $_.Name }
    return @($appNames)[0]
}