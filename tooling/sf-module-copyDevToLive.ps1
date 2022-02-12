. "$PSScriptRoot\constants.ps1"

$trg = "$sfPoshLivePath"
unlock-allFiles -path $trg
Remove-Item "$trg\*" -Force -Recurse
Copy-Item "$sfPoshDevPath\*" $trg -Recurse