$create = @(
    'proj-new.fromTFS.tests.ps1'
)

$initCreated = @(
    'sol-build.tests.ps1',
    'app-start.tests.ps1'
)

$mainTests = @(
    'app-reset.tests.ps1',
    'app-states.tests.ps1',
    'iis-subapp.tests.ps1',
    'proj-clone.tests.ps1',
    'proj-import.tests.ps1',
    'proj-rename.tests.ps1',
    'proj-new.fromZIP.tests.ps1'
)

$removeTests = @('proj-remove.tests.ps1')

$allTests = [System.Collections.Generic.List``1[string]]::new()

# $create | ForEach-Object { $allTests.Add($_) }
# $initCreated | ForEach-Object { $allTests.Add($_) }
$mainTests | ForEach-Object { $allTests.Add($_) }
# $removeTests | ForEach-Object { $allTests.Add($_) }

$allTests | ForEach-Object {
    Invoke-Pester "$PSScriptRoot/e2e/sf-$_"
}