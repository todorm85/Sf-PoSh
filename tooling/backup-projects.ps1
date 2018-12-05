. "$PSScriptRoot\load-module.ps1" prod

Import-Module "$PSScriptRoot\backup.psm1"
$logPath = "$home\Desktop\backup-projects-log.txt"

try {
    backup-liveSitefinities
}
catch {
    $_ | Out-File $logPath
}