$oldLoc = Get-Location
Set-Location "$PSScriptRoot"
try {
    Invoke-Pester -Tag "e2e"
}
catch {
    $_    
}

Set-Location $oldLoc