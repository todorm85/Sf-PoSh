function sf {
    param (
        [Parameter(ParameterSetName = "generic")][switch]$getLatestChanges,
        [Parameter(ParameterSetName = "generic")][switch]$forceGetChanges,
        [Parameter(ParameterSetName = "generic")][switch]$discardExistingChanges,
        [Parameter(ParameterSetName = "generic")][switch]$stopWhenNoNewChanges,
        [Parameter(ParameterSetName = "generic")][switch]$cleanSolution,
        [Parameter(ParameterSetName = "generic")][switch]$build,
        [Parameter(ParameterSetName = "generic")][switch]$resetApp,
        [Parameter(ParameterSetName = "generic")][switch]$resetPool,
        [Parameter(ParameterSetName = "generic")][switch]$precompile,
        [Parameter(ParameterSetName = "generic")][switch]$ensureRunning,
        [Parameter(ParameterSetName = "generic")][switch]$saveInitialState,
        [Parameter(ValueFromPipeline)]
        [SfProject]$project
    )
    
    Process {
        Run-InFunctionAcceptingProjectFromPipeline {
            $newChangesDetected = $forceGetChanges # force will always get new changes
            if ($discardExistingChanges -and (sf-sourceControl-hasPendingChanges)) {
                $output = sf-sourceControl-undoPendingChanges
                $newChangesDetected = $output.Exception -and !($output.Exception -notlike "*No pending changes*")
            }
        
            if ($getLatestChanges) {
                $getLatestOutput = sf-sourceControl-getLatestChanges -overwrite:$forceGet
                $newChangesDetected = !$getLatestOutput -or !($getLatestOutput.Contains('All files are up to date.'))
            }
        
            if (!$newChangesDetected -and $stopWhenNoNewChanges) {
                Write-Information "No new changes detected, stopping."
                return
            }

            if ($cleanSolution) {
                sf-sol-clean -cleanPackages $true
            }

            if ($build) {
                sf-sol-build -retryCount 3
            }

            if ($resetPool) {
                sf-iisAppPool-Reset
            }

            if ($resetApp) {
                sf-app-reinitialize
            }

            if ($precompile) {
                sf-appPrecompiledTemplates-add
                sf-app-sendRequestAndEnsureInitialized
            }

            if ($ensureRunning) {
                sf-app-sendRequestAndEnsureInitialized
            }

            if ($saveInitialState) {
                Start-Sleep -Seconds 1
                sf-appStates-save -stateName "init"
            }
        }
    }
}
