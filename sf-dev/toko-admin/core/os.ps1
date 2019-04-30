function os-popup-notification {
    Param (
        [Parameter(Mandatory = $false)][string] $msg = "No message provided."
    )

    return # off as it is annoying for now

    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

    $objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon 

    $objNotifyIcon.Icon = "${PSScriptRoot}\..\resources\icon.ico"
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
function execute-native ($command, [array]$successCodes) {
    $output = Invoke-Expression $command
    
    if ($Global:LASTEXITCODE -and -not ($successCodes -and $successCodes.Count -gt 0 -and $successCodes.Contains($Global:LASTEXITCODE))) {
        throw "Error executing native operation ($command). Last exit code was $Global:LASTEXITCODE. Native call output: $output`n"
    }
    else {
        $output
    }
}

function unlock-allFiles ($path) {
    if (!$path -or !(Test-Path $path)) {
        throw "The supplied path `"$path`" was not found.";
    }
    
    $handlesPath = "$PSScriptRoot\..\external-tools\handle.exe"
    if (!$handlesPath) {
        Write-Error "Handles tool not found. Unlocking open files will not work. Project files might need to be cleaned up manually if opened."
    }
    
    $handlesList = execute-native "& `"$handlesPath`" /accepteula `"$path`""
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
        Get-Process -Id $_ | % {
            # $date = [datetime]::Now
            # "$date : Forcing stop of process Name:$($_.Name) File:$($_.FileName) Path:$($_.Path) `nModules:$($_.Modules)" | Out-File "$home\Desktop\unlock-allFiles-log.txt" -Append
            Stop-Process $_ -Force -ErrorAction Continue
        }
    }
}