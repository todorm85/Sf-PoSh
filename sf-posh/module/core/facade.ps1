function sf {
    param (
        [Parameter(ParameterSetName = "new")][string]$newName,
        [Parameter(ParameterSetName = "new")][string]$newSourcePath,
        [Parameter(ParameterSetName = "discardAndSync")][switch]$discardChangesGetLatestBuildAndRun,
        [Parameter(ParameterSetName = "sync")][switch]$getLatestBuildAndRun,
        [Parameter(ValueFromPipeline)]
        [SfProject]$project
    )
    
    Process {
        if ($newName) {
            $project = $null
            if ($newSourcePath) {
                $project = sf-PSproject-new -sourcePath $newSourcePath -displayName $newName
            }
            else {
                $project = sf-PSproject-new -displayName $newName
            }

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
        [switch]$discardExisting
    )
    
    if ($project.branch) {
        if ($discardExisting -and (sf-source-hasPendingChanges)) {
            sf-source-undoPendingChanges
            $newChangesDetected = $true
        }

        $newChangesDetected = !(!(!(& git status | ? { $_ -contains "Your branch is up to date" })))
        if ($newChangesDetected) {
            sf-source-getLatestChanges
        }

        return $newChangesDetected
    }

    return $false
}