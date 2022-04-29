function sf-macros-prepareUnusedProjects {
    sf-project-get -all | ? displayName -eq '' | Run-InProjectScope -script {
        if (sf-git-isEnabled) {
            sf-paths-goto -root
            git restore *
            git clean -fd
            git pull
            sf-sol-clean;
            sf-sol-build;
            sf-app-reinitialize;
            sf-states-save init;
            Start-Sleep -Seconds 10;
        }
    }

    iisreset.exe
}

function sf-macros-resetProject {
    param(
        [switch]$skipBuild,
        [switch]$skipInit,
        [string]$branch = 'master',
        [Parameter(ValueFromPipeline)]
        [SfProject]$project
    )

    process {
        Run-InFunctionAcceptingProjectFromPipeline {
            param($project)
            Run-InProjectScope $project {
                sf-paths-goto -root
                git-resetAllChanges
                sf-git-checkout -branch $branch
                sf-sol-clean
                git pull -p
                if (!$skipBuild) {
                    sf-sol-build -retryCount 2
                    if (!$skipInit) {
                        sf-app-reinitialize
                        sf-states-save -stateName init
                    }
                }

                sf-project-rename
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

Register-ArgumentCompleter -CommandName sf-macros-resetProject -ParameterName newBranch -ScriptBlock $Script:branchCompleter

function sf-macros-resetAllEmptyNames {
    sf-project-get -all | ? displayName -eq '' | sf-macros-resetProject
}