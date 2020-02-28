param (
    [switch]$all,
    [switch]$create,
    [switch]$init,
    [switch]$main,
    [switch]$remove
)

$Script:allTests = @()

if ($all -or $create) { $Script:allTests += "$PSScriptRoot\e2e\creation" }
if ($all -or $init) { $Script:allTests += "$PSScriptRoot\e2e\initialize" }
if ($all -or $main) { $Script:allTests += "$PSScriptRoot\e2e\main" }
if ($all -or $remove) { $Script:allTests += "$PSScriptRoot\e2e\removal" }

$Script:allTests | ForEach-Object {
    Invoke-Pester $_
}