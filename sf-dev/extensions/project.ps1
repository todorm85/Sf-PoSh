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
        sol-rebuild -cleanPackages:$true -retryCount 3
        app-reset
        app-addPrecompiledTemplates
        states-save -stateName initial
    }
}
