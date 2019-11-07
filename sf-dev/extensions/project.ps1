<#
.SYNOPSIS
Undos all pending changes, gets latest, builds and initializes.
#>
function proj-reset {
    $shouldReset = $false
    if (sc-hasPendingChanges) {
        sc-undoPendingChanges
        $shouldReset = $true
    }

    $getLatestOutput = sc-getLatestChanges -overwrite
    if (-not ($getLatestOutput.Contains('All files are up to date.'))) {
        $shouldReset = $true
    }

    if ($shouldReset) {
        sol-clean -cleanPackages $true
        app-reset
        sol-rebuild
        app-addPrecompiledTemplates
        states-save -stateName initial
    }
}
