function os-popup-notification {
    Param (
            [Parameter(Mandatory=$false)][string] $msg = "No message provided."
        )

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

    if ($items.PSPath -eq '' -or $items.PSPath -eq $null) {
        $paths = $items   
    } else {
        $paths = $items.PSPath
    }

    if ($paths -eq $null) {
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
    $isUsed = $false
    ForEach ($socket in $openedSockets) {
        if ($socket.localPort -eq $port) {
            $isUsed = $true
            break
        }
    }

    return $isUsed
}
