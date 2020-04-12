function sf {
    [CmdletBinding()]
    param (
        [switch]$getLatest,
        [switch]$forceGet,
        [switch]$stopIfNoNew,
        [switch]$discardExisting,
        [switch]$clean,
        [switch]$build,
        [switch]$reinitialize,
        [switch]$resetPool,
        [switch]$start,
        [switch]$precompile,
        [switch]$save,
        [Parameter(ValueFromPipeline)][SfProject]$project
        )
    
    Process {
        if (!$getLatest -and !$clean -and !$build -and !$reinitialize -and !$resetPool -and !$start -and !$precompile -and !$save) {
            sd-project-select
        }

        if (!$project) {
            $project = sd-project-getCurrent
            if (!$project) {
                sd-project-select
            }

            $project = sd-project-getCurrent
            if (!$project) {
                sd-project-new
            }
        }
        else {
            sd-project-setCurrent $project > $null
        }
        
        if ($getLatest) {
            $newChangesDetected = $false
            if ($discardExisting -and (sd-sourceControl-hasPendingChanges)) {
                sd-sourceControl-undoPendingChanges
                $newChangesDetected = $true
            }
            
            $getLatestOutput = sd-sourceControl-getLatestChanges -overwrite:$forceGet
            if (!$getLatestOutput -or !($getLatestOutput.Contains('All files are up to date.'))) {
                $newChangesDetected = $true
            }
            
            $project.lastGetLatest = [DateTime]::Now
            sd-project-save -context $project
        
            if (!$newChangesDetected -and $stopIfNoNew) {
                Write-Information "No new changes detected, stopping."
            }
        }
        
        if ($clean) {
            sd-sol-clean -cleanPackages $true
        }

        if ($build) {
            sd-sol-build -retryCount 3
        }

        if ($resetPool) {
            sd-iisAppPool-Reset
        }
        if ($reinitialize) {
            sd-app-reinitializeAndStart
        }
        elseif ($start) {
            sd-app-waitForSitefinityToStart
        }

        if ($precompile) {
            sd-appPrecompiledTemplates-add
        }
        else {
            sd-appPrecompiledTemplates-remove
        }

        if ($save) {
            Start-Sleep -Seconds 2
            sd-appStates-save -stateName "init"
        }
    }
}
