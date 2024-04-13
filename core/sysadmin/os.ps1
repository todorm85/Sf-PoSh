$Script:hostsPath = "$($env:windir)\system32\Drivers\etc\hosts"

# Get the Handle.exe tool by Sysinternals
$handleLink = "https://download.sysinternals.com/files/Handle.zip"
$handleExternalToolsDir = "$Script:moduleUserDir\external-tools\handle"
if (!(Test-Path $handleExternalToolsDir)) {
    New-Item -Path $handleExternalToolsDir -ItemType Directory
}

$handleToolPath = "$handleExternalToolsDir\handle.exe"
if (!(Test-Path $handleToolPath)) {
    $archive = "$handleExternalToolsDir\Handle.zip"
    try {
        Invoke-WebRequest -Uri $handleLink -OutFile $archive
        expand-archive -path $archive -destinationpath $handleExternalToolsDir
        . "$handleExternalToolsDir\Eula.txt"
        Remove-Item -Path $archive -Force
    }
    catch {
        Write-Error "Error fetching the handle tool from $handleLink auto unlocking files will not work."
    }
}

function os-popup-notification {
    Param (
        [Parameter(Mandatory = $false)][string] $msg = "No message provided."
    )

    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

    $objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon

    $objNotifyIcon.Icon = "${PSScriptRoot}\resources\icon.ico"
    $objNotifyIcon.BalloonTipIcon = "Info"
    $objNotifyIcon.BalloonTipText = $msg
    $objNotifyIcon.BalloonTipTitle = "Powershell operation done."

    $objNotifyIcon.Visible = $True
    $objNotifyIcon.ShowBalloonTip(10000)
}

function os-test-isPortFree {
    Param($port)

    $openedSockets = Get-NetTCPConnection -State Listen
    $isFree = $true
    ForEach ($socket in $openedSockets) {
        if ($socket.localPort -eq $port) {
            $isFree = $false
            break
        }
    }

    return $isFree
}

<#
.EXAMPLE
$path = "tf.exe"
execute-native "& `"$path`" workspaces `"C:\dummySubApp`""
#>
function execute-native ([string]$command, [array]$successCodes, [switch]$doNotThrowError) {
    $command = $command + " 2>&1"
    $output = Invoke-Expression $command

    if (!$doNotThrowError -and $lastexitcode -and -not ($successCodes -and $successCodes.Count -gt 0 -and $successCodes.Contains($lastexitcode))) {
        throw "Error executing native operation ($command). Last exit code was $lastexitcode. Native call output: $output`n"
    }
    else {
        $output
    }
}

function unlock-allFiles ($path) {
    if (!$path -or !(Test-Path $path)) {
        throw "The supplied path `"$path`" was not found.";
    }

    if (!(Test-Path $handleToolPath)) {
        Write-Error "Handles tool not found. Unlocking open files will not work. Project files might need to be cleaned up manually if opened."
    }

    # sent async to prevent handles tool from getting locked by the process
    $unlockFilesJob = {
        $result = Invoke-Expression "& `"$($args[0])`" /accepteula `"$($args[1])`" 2>&1"
        return $result
    }

    $handlesList = _executeJobAsync $unlockFilesJob
    $pids = New-Object -TypeName System.Collections.ArrayList
    $handlesList | ForEach-Object {
        $isFound = $_ -match "^.*pid: (?<pid>.*?) .*$"
        if ($isFound) {
            $id = $Matches.pid
            if (-not $pids.Contains($id)) {
                $pids.Add($id) > $null
            }
        }
    }

    $pids | ForEach-Object {
        Get-Process -Id $_ -ErrorAction SilentlyContinue | ForEach-Object {
            # $date = [datetime]::Now
            # "$date : Forcing stop of process Name:$($_.Name) File:$($_.FileName) Path:$($_.Path) `nModules:$($_.Modules)" | Out-File "$home\Desktop\unlock-allFiles-log.txt" -Append
            Stop-Process $_ -Force
        }
    }
}

function os-hosts-add ($hostname, $address = '127.0.0.1') {
    if (!$hostname) {
        return
    }

    unlock-allFiles -path $Script:hostsPath
    If ((Get-Content $Script:hostsPath) -notcontains "$address $hostname") {
        Add-Content -Encoding utf8 $Script:hostsPath "$address $hostname" -ErrorAction Stop
    }
}

function os-hosts-get {
    Get-Content $Script:hostsPath
}

function os-hosts-remove ($hostname) {
    if (!$hostname) {
        return
    }

    $address = $null
    (Get-Content $Script:hostsPath) | ForEach-Object {
        $found = $_ -match "^(?<address>.*?) $hostname$"
        if ($found) {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Justification = "False positive")]
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

function os-browseUrl {
    param (
        [string]$url,
        [switch]$openInSameWindow
    )

    $browserPath = $GLOBAL:sf.config.browserPath
    if (!$openInSameWindow) {
        & Start-Process "$browserPath"
        Start-Sleep -Seconds 1
    }

    # & "$browserPath" "$url" -noframemerging --profile-directory="Profile 1"
    & "$browserPath" "$url" -noframemerging
}

function _clean-emptyDirs ($path) {
    $dirs = @()
    do {
        $dirs | ForEach-Object { Remove-Item $_ -Force }
        $failed = @($dirs | ? { Test-Path $_ })
        $failed | ForEach-Object { Remove-Item $_ -Force }
        $failed = @($failed | ? { Test-Path $_ })
        $dirs = Get-ChildItem -Path $path -directory -recurse | `
            Where-Object { (Get-ChildItem $_.fullName).Count -eq 0 -and !$failed.Contains($_.FullName) } | `
            Select-Object -expandproperty FullName
    } while ($dirs.count -gt 0)
}

function _executeJobAsync ($script) {
    $job = Start-Job -ScriptBlock $script -ArgumentList $handleToolPath, $path | Wait-Job
    Receive-Job -Job $job
}
