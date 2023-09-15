. "$PSScriptRoot\constants.ps1"
sf-update-moduleDefinitions.ps1
$trg = "$sfPoshLivePath"
unlock-allFiles -path $trg
Remove-Item "$trg\*" -Force -Recurse
Copy-Item "$sfPoshDevPath\*" $trg -Recurse
sf-update-moduleDefinitions.ps1 -exportPrivate