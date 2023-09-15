. constants.ps1
sf-module-updateDefinitions.ps1
$trg = $sfPoshLivePath
unlock-allFiles -path $trg
Remove-Item "$trg\*" -Force -Recurse
Copy-Item "$sfPoshDevPath\*" $trg -Recurse