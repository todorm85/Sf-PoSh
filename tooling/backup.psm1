$backupTarget = "D:\sitefinities-backup"
if (-not (Test-Path $backupTarget)) {
    New-Item $backupTarget -ItemType Directory
}

function backup-liveDb {
    $suffix = [DateTime]::Now.Ticks
    $dbTarget = "$backupTarget\db_$suffix.xml"
    Copy-Item "C:\sf-dev\db.xml" $dbTarget
}

function backup-liveSitefinities {
    $errors = ''
    $toCleanUp = Get-Item $backupTarget | ForEach-Object {$_.GetDirectories()} | Sort-Object -Property LastWriteTime -Descending | Select-Object -Skip 5
    if ($toCleanUp -and $toCleanUp.length -gt 0) {
        try {
            os-del-filesAndDirsRecursive $toCleanUp
        }
        catch {
            $errors = $_
        }
    }

    $suffix = [DateTime]::Now.Ticks
    $sfBackupContainerTarget = "$backupTarget\backup_$suffix"
    New-Item $sfBackupContainerTarget -ItemType Directory

    $dbTarget = "$sfBackupContainerTarget\db.xml"
    Copy-Item "C:\sf-dev\db.xml" $dbTarget

    $scriptBlock = {
        Param([SfProject]$sf)
        $src = If ($sf.solutionPath) {$sf.solutionPath} else {$sf.webAppPath}
        Copy-Item "$src\*" "$sfBackupContainerTarget\$($sf.id)" -Recurse
        "$($sf.id) original location: $src" | Out-File "$sfBackupContainerTarget\BACKUP-INFO.txt" -Append
    }

    try {
        sf-start-allProjectsBatch $scriptBlock
    }
    catch {
        $errors = "$errors`n-----------------------`n$_"        
    }

    if ($errors) {
        throw $errors
    }
}

function pubfunc {
    Write-Host 'public'    
}