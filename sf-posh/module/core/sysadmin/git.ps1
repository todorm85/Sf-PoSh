
function git-clone {
    param (
        $remotePath,
        $localPath,
        $directoryName
    )

    RunInLocation $localPath {
        Invoke-Expression -Command "git clone $remotePath $directoryName"
    }
}

function git-getAllBranches {
    $jobName = 'branchCacheTimeout';
    $job = get-job -Name $jobName -ErrorAction SilentlyContinue
    if ($job) {
        if ($Script:branchesCache -and $job.State -ne 'Completed') {
            return $Script:branchesCache
        }
        else {
            Remove-Job -Name $jobName -Force
        }
    }

    $Script:branchesCache = git branch -a | % { $_.Trim().Trim('*').Trim().Replace("remotes/origin/", '') }
    $job = Start-Job -ScriptBlock { Start-Sleep -Seconds 60 } -Name $jobName
    $Script:branchesCache
}

function git-completeBranchName {
    param($wordToComplete)
    $possibleValues = git-getAllBranches
    if ($wordToComplete) {
        $possibleValues = $possibleValues | Where-Object {
            $_ -like "$wordToComplete*"
        }
    }

    $possibleValues
}

function git-getAllLocalBranches {
    param(
        [switch]$skipDefaults
    )
    
    RunInRootLocation {
        $res = git branch | % { $_.Trim('*').Trim() }
        if ($skipDefaults) {
            $res = $res | ? { $_ -ne 'master' -and $_ -ne "patches" }
        }
        
        $res
    }
}

function git-getCurrentBranch {
    $res = git branch 2>&1
    if (!$res.Exception) {
        $res | ? { $_.StartsWith("*") } | % { $_.Split(' ')[1] }
    }
    else {
        Write-Warning "Error getting project branch in $(Get-Location).`n Error is: $($res.Exception.Message)"
    }
}

function git-resetAllChanges {
    git restore --staged *
    git restore *
    git clean -fd
}
