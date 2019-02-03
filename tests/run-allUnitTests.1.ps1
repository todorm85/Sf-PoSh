$oldLoc = Get-Location
Set-Location "$PSScriptRoot"
try {
    Invoke-Pester -ExcludeTag "e2e"
}
catch {
    $_    
}

Set-Location $oldLoc