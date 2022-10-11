function sf-macros-resetProject {
    param(
        [switch]$force,
        [switch]$skipBuild,
        [switch]$skipInit,
        [switch]$skipSourceUpdate,
        $branch,
        [Parameter(ValueFromPipeline)]
        [SfProject]$project
    )
        
    process {
        Run-InFunctionAcceptingProjectFromPipeline {
            param($project)
            Run-InProjectScope $project {
                RunInRootLocation {
                    Write-Information "`n$($project.id): Starting reset.`n"

                    if ($branch -and $branch -ne (sf-git-getCurrentBranch)) {
                        sf-git-cleanDevArtefacts
                        Write-Information "$($project.id): Switching to branch $branch"
                        sf-git-checkout -branch $branch
                    }

                    if (!$force -and (sf-git-isClean) -and !(sf-git-isBehind) -and (sf-app-isInitialized)) {
                        Write-Information "`n$($project.id) is clean and not behind and running skipping update."
                    }
                    else {
                        Write-Information "`n$($project.id): Resetting"
                        git-resetAllChanges
                        Write-Information "$($project.id): Cleaning solution."
                        sf-sol-clean
                        if (!$skipSourceUpdate) {
                            Write-Information "$($project.id): Pulling latest."
                            git pull
                        }
                        
                        if (!$skipBuild) {
                            Write-Information "$($project.id): Build started."
                            sf-sol-build -retryCount 2
                            Write-Information "$($project.id): Build complete."
                            if (!$skipInit) {
                                Write-Information "$($project.id): Reinitializing app."
                                $waitTime = $GLOBAL:sf.config.app.startupMaxWait
                                $GLOBAL:sf.config.app.startupMaxWait = 5 * 60
                                sf-app-reinitialize
                                $GLOBAL:sf.config.app.startupMaxWait = $waitTime
                                sf-states-save -stateName init
                            }
                        }
                    }

                    Write-Information "`n$($project.id): Resetting finished.`n"
                }
            }
        }
    }
}

Register-ArgumentCompleter -CommandName sf-macros-resetProject -ParameterName branch -ScriptBlock $Script:branchCompleter

function sf-macros-applyLatestChanges {
    param(
        [switch]$mergeBranch,
        [switch]$force,
        [switch]$skipBuild,
        [switch]$skipInit,
        [Parameter(ValueFromPipeline)]
        [SfProject]$project
    )

    process {
        Run-InFunctionAcceptingProjectFromPipeline {
            param($project)
            Run-InProjectScope $project {
                RunInRootLocation {
                    Write-Information "$($project.id): Starting applying latest changes."
                    if ($force) {
                        sf-git-resetAllChanges
                    }
                    
                    $wasClean = sf-git-isClean
                    if (!$wasClean) {
                        throw "$($project.id): Git not clean."
                    }

                    git fetch
                    $isRemoteUpToDate
                    if ($mergeBranch) {
                        Write-Information "$($project.id): Merging origin/$mergeBranch"
                        $res = git merge origin/$mergeBranch
                        $isRemoteUpToDate = $res -eq "Already up to date."
                    }

                    $wasBehind = sf-git-isBehind
                    if (!$wasBehind -and $isRemoteUpToDate) {
                        Write-Information "$($project.id): Project is clean and up to date with remote."
                    }
                    else {
                        Write-Information "$($project.id): Cleaning solution."
                        sf-sol-clean
                        Write-Information "$($project.id): Pulling latest."
                        git pull
                        if (!$skipBuild) {
                            Write-Information "$($project.id): Build started."
                            sf-sol-build -retryCount 2
                            Write-Information "$($project.id): Build complete."
                            if (!$skipInit) {
                                Write-Information "$($project.id): Backup state before reset."
                                ss -stateName "backup"
                                Write-Information "$($project.id): Reinitializing app."
                                sf-app-reinitialize
                                sf-states-save -stateName init
                            }
                        }
                    }
                }

                Write-Information "`n$($project.id): Resetting finished.`n"
            }
        }
    }
}

function sf-macros-getAllUnused {
    sf-project-get -all | ? displayName -eq ''
}

function sf-macros-setMasterOrPatchesBranchAndResetForAllUnused {
    $errorsFromReset = @()
    sf-macros-runForUnusedProjects {
        $branch = sf-git-getCurrentBranch
        if (-not ($branch -eq 'master' -or $branch -eq 'patches')) {
            $branch = 'master'
        }
                
        sf-macros-resetProject -branch $branch
    }
}

function sf-macros-runForUnusedProjects {
    param($script)
    try {
        sf-macros-getAllUnused | Run-InProjectScope -script $script -ErrorVariable +errors -ErrorAction SilentlyContinue
    }
    catch {
        throw $errors += $_
    }
    finally {
        if ($errors) {
            $errors = "Errors.`n $errors";
            $errors
        }
    }
}
