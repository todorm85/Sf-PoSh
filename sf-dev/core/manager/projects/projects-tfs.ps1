# IMPORTANT: this is called in daily cleanup
function Update-AllProjectsTfsInfo {
    $sfs = Get-AllProjects
    $sfs | ForEach-Object {
        
        [SfProject]$context = $_

        UpdateLastGetLatest $context

        $branch = tfs-get-branchPath $context.webAppPath
        if ($branch) {
            $context.branch = $branch
            SetProjectData $context
        }
    }
}

function UpdateLastGetLatest {
    param (
        [SfProject]$context
    )
    
    $lastGetLatestTfs = GetLastWorkspaceChangesetDate $context
    if ($lastGetLatestTfs) {
        if ($context.lastGetLatest) {
            $lastGetLatestTool = [datetime]::Parse($context.lastGetLatest)
            
            # only update if not get-latest issued already from this tool later than what is in workspace
            if ($lastGetLatestTool -lt $lastGetLatestTfs) {
                $context.lastGetLatest = $lastGetLatestTfs
                SetProjectData $context
            }
        }
        else {
            $context.lastGetLatest = $lastGetLatestTfs
            SetProjectData $context
        }
    }
}

function GetLastWorkspaceChangesetDate ([SfProject]$context) {
    if (-not $context) {
        [SfProject]$context = Get-CurrentProject
    }

    if (-not $context.solutionPath) {
        return
    }

    try {
        #TFS returns only the day. not time
        $changesetInfo = tfs-get-lastWorkspaceChangeset $context.solutionPath
    }
    catch {
        Write-Warning "Unable to retrieve latest changeset from workspace, fallback to last time get-latest command was issued in this tool."        
    }

    if ($changesetInfo -and $changesetInfo[2]) {
        $hasDate = $changesetInfo[2] -match "^.+ (?<date>\d{1,2}\/\d{1,2}\/\d{4}) .*$"
        if ($hasDate) {
            return [datetime]::Parse($Matches.date)
        }
    }
}
