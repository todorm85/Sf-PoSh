function sf {
    param (
        [Parameter(ParameterSetName = "new")][string]$newSourcePath,
        [Parameter(ParameterSetName = "new")][string]$newName = 'Untitled',
        [Parameter(ParameterSetName = "recreate")][switch]$recreate,
        [Parameter(ParameterSetName = "discardAndSync")][switch]$discardChangesGetLatestBuildAndRun,
        [Parameter(ParameterSetName = "sync")][switch]$getLatestBuildAndRun,
        [Parameter(ValueFromPipeline)]
        [SfProject]$project
    )
    
    Process {
        if ($newSourcePath) {
            $project = sf-PSproject-new -sourcePath $newSourcePath -displayName $newName
            if (!(Test-Path "$($project.webAppPath)/bin/Telerik.Sitefinity.dll")) {
                sf-sol-build -retryCount 3
            }
            
            if (!(sf-app-isInitialized)) {                    
                sf-app-reinitialize
                sf-states-save "init_$(Get-Date -Format 'dd_MMM_yy')"
            }

            return
        }

        Run-InFunctionAcceptingProjectFromPipeline {
            param($project)

            if ($getLatestBuildAndRun) {
                sf-precompiledTemplates-remove
                if (_facade-source-getLatest $project) {
                    sf-sol-build -retryCount 3
                    Start-Sleep -Seconds 1
                    sf-app-ensureRunning
                }

                return
            }

            if ($recreate) {
                _facade-source-getLatest -project $project -force -discardExisting
                sf-sol-clean
                sf-sol-build -retryCount 3
                sf-app-reinitialize
                Start-Sleep -Seconds 1
                sf-app-ensureRunning
                Start-Sleep -Seconds 1
                sf-states-save -stateName init
                return
            }

            if ($discardChangesGetLatestBuildAndRun) {
                sf-precompiledTemplates-remove
                if (_facade-source-getLatest $project -discardExisting) {
                    sf-sol-build -retryCount 3
                    Start-Sleep -Seconds 1
                    sf-app-ensureRunning
                }

                return
            }
        }
    }
}

Register-ArgumentCompleter -CommandName sf -ParameterName newSourcePath -ScriptBlock {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )

    $values = $sf.config.predefinedBranches
    $values += $sf.config.predefinedBuildPaths
    $values | % { "'$_'" }
}

function _facade-source-getLatest {
    param (
        [SfProject]$project,
        [switch]$force,
        [switch]$discardExisting
    )
    
    if ($project.branch) {
        $newChangesDetected = $force # force will always get new changes
        if ($discardExisting -and (sf-source-hasPendingChanges)) {
            $output = sf-source-undoPendingChanges
            $newChangesDetected = $output.Exception -and !($output.Exception -notlike "*No pending changes*")
        }

        if ($getLatestChanges) {
            $getLatestOutput = sf-source-getLatestChanges -overwrite:$force
            $newChangesDetected = !$getLatestOutput -or !($getLatestOutput.Contains('All files are up to date.'))
        }

        return $newChangesDetected
    }

    return $false
}