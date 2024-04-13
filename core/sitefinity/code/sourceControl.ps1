function sf-git-removeBranches {
    param (
        $startsWith = 'tmitskov/'
    )
    
    RunInRootLocation {
        git branch | % {$_.TrimStart()} | ? {$_.StartsWith($startsWith)} | % { git branch -d $_}
    }
}

function sf-git-isClean {
    param(
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project
    )
    
    process {
        Run-InFunctionAcceptingProjectFromPipeline {
            param($project)
            
            sf-git-cleanDevArtefacts            
            $changes = sf-git-status
            $changes.Count -eq 0
        }
    }
}

function sf-git-isBehind {
    param(
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project
    )
    
    process {
        Run-InFunctionAcceptingProjectFromPipeline {
            param($project)
            
            RunInRootLocation {
                git fetch
                $status = git status
                if ($status -like "Your branch is behind*") {
                    return $true
                } else {
                    return $false
                }
            }
        }
    }
}

function sf-git-cleanDevArtefacts {
    RunInRootLocation {
        $ignoredPaths = @(".nuget/NuGet.Config",
        "Builds/StyleCop/StyleCop.Targets",
        "Feather/Tests/Telerik.Sitefinity.Frontend.ClientTest/obj/Debug/DesignTimeResolveAssemblyReferencesInput.cache",
        "Builds/StyleCop/StyleCop.Targets")
        $ignoredPaths | % { git restore $_ }

        $trxFile = "SitefinityWebApp/results.trx"
        if (Test-Path $trxFile) {
            Remove-Item -Path $trxFile
        }

        Get-ChildItem | ? Name -match "sf.*?\d+?\.sln" | select -ExpandProperty FullName | Remove-Item -Force
    }
}

function sf-git-status {
    RunInRootLocation {
        $rawOutput = git status
        $statusContext = ""
        $changes = @()
        foreach ($line in $rawOutput) {
            # context
            if ($line -like "Changes not staged for commit*") {
                $statusContext = "notStaged"
                continue
            }
            
            if ($line -like "Untracked files:*") {
                $statusContext = "untracked"
                continue
            }

            if ($line -like "Changes to be committed:*") {
                $statusContext = "staged"
                continue
            }

            #process context
            if ($statusContext -eq "notStaged" -or $statusContext -eq "staged") {
                if ($line -like '*(use "git*') {
                    continue
                }
                elseif ($line -and $line -match "^\s?.*") {
                    $parts = $line -split ": " | ? { -not [string]::IsNullOrWhiteSpace($_) }
                    if ($parts.Count -ne 2) {
                        throw "unexpected line";
                    }

                    $changes += [PSCustomObject]@{type = $parts[0].Trim(); path = $parts[1].Trim() }
                    continue
                }
                elseif (!$line) {
                    $statusContext = ''
                }
                else {
                    throw "Unexpected character."
                }
            }

            if ($statusContext -eq "untracked") {
                if ($line -like '*(use "git*') {
                    continue
                }
                elseif ($line -and $line -match "^\s?.+") {
                    $changes += [PSCustomObject]@{type = "untracked"; path = $line.Trim() }
                    continue
                }
                elseif (!$line) {
                    $statusContext = ''
                }
                else {
                    throw "Unexpected character."
                }
            }
        }

        $changes
    }
}

function sf-git-getCurrentBranch {
    RunInRootLocation {
        $res = git-getCurrentBranch
        if (!$res.StartsWith("fatal")) {
            $res
        }
    }
}

function sf-git-isEnabled {
    RunInRootLocation {
        Test-Path ".\.git"
    }
}

function sf-git-resetAllChanges {
    RunInRootLocation {
        git-resetAllChanges
    }
}

function sf-git-checkout {
    param (
        $branch
    )

    RunInRootLocation {
        $branchExists = git-getAllBranches | ? { $_ -eq $branch }
        if ($branchExists) {
            $res = git checkout $branch 2>&1
        }
        else {
            $res = git checkout -b $branch 2>&1
        }
        
        if ($res | ? { $_.Exception -and $_.Exception.Message.StartsWith("Switched to") }) {
            $p = sf-project-get
            $p.branch = $branch
            _update-prompt $p
        }
        else {
            Write-Error "Something went wrong: $res"
        }
    }
}

Register-ArgumentCompleter -CommandName sf-git-checkout -ParameterName branch -ScriptBlock $Script:branchCompleter

function sf-git-getCommitsBehind {
    param (
        $branch
    )

    RunInRootLocation {
        git fetch
        if ($branch) {
            + (git rev-list --count HEAD ^$branch)
        }
        else {

            $commitsCount = (git status) -like "Your branch is behind*" | % { $_ -match "Your branch is behind 'origin/.*?' by (?<commits>\d+)? commits" | Out-Null; + $Matches['commits'] }
            if (!$commitsCount) { $commitsCount = 0 }
            $commitsCount
        }
    }
}

Register-ArgumentCompleter -CommandName sf-git-getCommitsBehind -ParameterName branch -ScriptBlock $Script:branchCompleter
