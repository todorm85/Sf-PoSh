. "$PSScriptRoot\load-module.ps1" prod
Import-Module "$PSScriptRoot\backup.psm1"
$logPath = "$home\Desktop\live-db-backup-log.txt"

try {
    backup-liveDb
}
catch {
    $_ | Out-File $logPath
}