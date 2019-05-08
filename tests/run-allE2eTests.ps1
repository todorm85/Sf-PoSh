$oldLoc = Get-Location
Set-Location "$PSScriptRoot"
try {
    Invoke-Pester -Tag "e2e-fluent"
}
catch {
    $_    
}

Set-Location $oldLoc