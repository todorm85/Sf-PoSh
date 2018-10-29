function os-popup-notification {
    Param (
        [Parameter(Mandatory = $false)][string] $msg = "No message provided."
    )
        
    # Stopping for now as it is very annoying how taskbar icons are left out and cannot be hidden.
    return;

    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

    $objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon 

    $objNotifyIcon.Icon = "${PSScriptRoot}\resources\check.ico"
    $objNotifyIcon.BalloonTipIcon = "Info"
    $objNotifyIcon.BalloonTipText = $msg
    $objNotifyIcon.BalloonTipTitle = "Powershell operation done."
     
    $objNotifyIcon.Visible = $True 
    $objNotifyIcon.ShowBalloonTip(10000)
}

function os-del-filesAndDirsRecursive {
    Param($items) 

    if ($items.PSPath -eq '' -or $null -eq $items.PSPath) {
        $paths = $items   
    }
    else {
        $paths = $items.PSPath
    }

    if ($null -eq $paths) {
        throw "No files or folders to delete"
    }

    Remove-Item $items.PSPath -force -recurse -ErrorAction SilentlyContinue -ErrorVariable ProcessError
    if ($ProcessError) {
        throw $ProcessError
    }
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
