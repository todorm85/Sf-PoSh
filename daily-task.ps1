& "$PSScriptRoot\sf-dev-profile.ps1" prod

$logPath = "$home\Desktop\sf-dev-log.txt"

function add-toLog $text {
    $text | Out-File $logsPath -Append
}

if (Test-Path $logPath) {
    unlock-allFiles $logPath
    Remove-Item $logPath -Force
}

try {
    backup-live
}
catch {
    add-toLog "Error with backup: $_"
}

try {
    clear-nugetCache
}
catch {
    add-toLog "Error clearing nugt cache: $_"
}

try {
    sf-update-allProjectsTfsInfo
}
catch {
    add-toLog "Error updating projects TFS info from TFS: $_"
}

try {
    global:batchOverwriteProjectsWithLatestFromTfsIfNeeded
}
catch {
    add-toLog "Error with projects batch: $_"
}
