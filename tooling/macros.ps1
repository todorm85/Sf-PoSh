function sf-macros-applyLatestForUnusedProjects {
    sf-project-get -all | ? displayName -eq '' | sf-macros-applyLatestChanges
    iisreset.exe
}

function sf-macros-resetProject {
    param(
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
                    Write-Host "`n$($project.id): Resetting"
                    git-resetAllChanges
                
                    if ($branch -and $branch -ne (sf-git-getCurrentBranch)) {
                        Write-Host "$($project.id): Switching to branch $branch"
                        sf-git-checkout -branch $branch
                    }
                
                    Write-Host "$($project.id): Cleaning solution."
                    sf-sol-clean
                    if (!$skipSourceUpdate) {
                        Write-Host "$($project.id): Pulling latest."
                        git pull
                    }
                        
                    if (!$skipBuild) {
                        Write-Host "$($project.id): Build started."
                        sf-sol-build -retryCount 2
                        Write-Host "$($project.id): Build complete."
                        if (!$skipInit) {
                            Write-Host "$($project.id): Reinitializing app."
                            $waitTime = $GLOBAL:sf.config.app.startupMaxWait
                            $GLOBAL:sf.config.app.startupMaxWait = 5 * 60
                            sf-app-reinitialize
                            $GLOBAL:sf.config.app.startupMaxWait = $waitTime
                            sf-states-save -stateName init
                        }
                    }

                    Write-Information "`n$($project.id): Resetting finished.`n"
                }
            }
        }
    }
}

$Script:branchCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )
        
    git-completeBranchName $wordToComplete
}

Register-ArgumentCompleter -CommandName sf-macros-resetProject -ParameterName branch -ScriptBlock $Script:branchCompleter

function sf-macros-resetAllUnused {
    sf-project-get -all | ? displayName -eq '' | % {
        Run-InProjectScope -project $_ {
            $branch = sf-git-getCurrentBranch
            if (-not ($branch -eq 'master' -or $branch -eq 'patches')) {
                $branch = 'master'
            }

            sf-macros-resetProject -branch $branch
        }
    }
}

function sf-macros-applyLatestChanges {
    param(
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
                    Write-Host "$($project.id): Starting applying latest changes."
                    $wasClean = sf-git-isClean
                    if (!$wasClean) {
                        throw "$($project.id): Git not clean."
                    }
                    
                    if (sf-git-isUpToDateWithRemote) {
                        Write-Host "$($project.id): Project is clean and up to date with remote."
                    }
                    else {
                        Write-Host "$($project.id): Cleaning solution."
                        sf-sol-clean
                        Write-Host "`n$($project.id): Resetting all build artefact changes."
                        git-resetAllChanges
                        Write-Host "$($project.id): Pulling latest."
                        git pull
                        
                        if (!$skipBuild) {
                            Write-Host "$($project.id): Build started."
                            sf-sol-build -retryCount 2
                            Write-Host "$($project.id): Build complete."
                            if (!$skipInit) {
                                Write-Host "$($project.id): Reinitializing app."
                                sf-app-reinitialize
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
