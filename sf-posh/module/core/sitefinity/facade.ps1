function sf {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = "recreate")][switch]$recreate,
        [Parameter(ParameterSetName = "startNew")][switch]$startNew,
        [Parameter(ParameterSetName = "sync")][switch]$sync,
        [Parameter(ParameterSetName = "generic")][switch]$getLatest,
        [Parameter(ParameterSetName = "generic")][switch]$forceGet,
        [Parameter(ParameterSetName = "generic")][switch]$discardExisting,
        [Parameter(ParameterSetName = "generic")][switch]$abortNoNew,
        [Parameter(ParameterSetName = "generic")][switch]$clean,
        [Parameter(ParameterSetName = "generic")][switch]$build,
        [Parameter(ParameterSetName = "generic")][switch]$reinitialize,
        [Parameter(ParameterSetName = "reset")][switch]$reset,
        [Parameter(ParameterSetName = "generic")][switch]$precompile,
        [Parameter(ParameterSetName = "start")][switch]$start,
        [Parameter(ParameterSetName = "generic")][switch]$save,
        [Parameter(ValueFromPipeline)]
        [SfProject]$project
    )
    
    Process {
        SfPoshProcess {
            if ($sync) {
                sf-appPrecompiledTemplates-remove
                sf -getLatest -abortNoNew -build
                sf-app-sendRequestAndEnsureInitialized
                return
            }

            if ($recreate) {
                sf -getLatest -forceGet -discardExisting -clean -build -reinitialize -precompile -save
                return
            }

            if ($startNew) {
                sf-appPrecompiledTemplates-remove
                sf -getLatest -discardExisting -abortNoNew -build
                sf-app-sendRequestAndEnsureInitialized
                return
            }

            $newChangesDetected = $forceGet # force will always get new changes
            if ($discardExisting -and (sf-sourceControl-hasPendingChanges)) {
                $output = sf-sourceControl-undoPendingChanges
                $newChangesDetected = $output.Exception -and !($output.Exception -notlike "*No pending changes*")
            }
        
            if ($getLatest) {
                $getLatestOutput = sf-sourceControl-getLatestChanges -overwrite:$forceGet
                $newChangesDetected = !$getLatestOutput -or !($getLatestOutput.Contains('All files are up to date.'))
            }
        
            if (!$newChangesDetected -and $abortNoNew) {
                Write-Information "No new changes detected, stopping."
                return
            }

            if ($clean) {
                sf-sol-clean -cleanPackages $true
            }

            if ($build) {
                sf-sol-build -retryCount 3
            }

            if ($reset) {
                sf-iisAppPool-Reset
            }

            if ($reinitialize) {
                sf-app-reinitialize
            }

            if ($precompile) {
                sf-appPrecompiledTemplates-add
                sf-app-sendRequestAndEnsureInitialized
            }

            if ($start) {
                sf-app-sendRequestAndEnsureInitialized
            }

            if ($save) {
                Start-Sleep -Seconds 1
                sf-appStates-save -stateName "init"
            }
        }
    }
}
