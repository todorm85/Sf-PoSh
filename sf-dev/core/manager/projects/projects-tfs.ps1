# IMPORTANT: this is called in daily cleanup
function sf-update-allProjectsTfsInfo {
    $sfs = _sfData-get-allProjects
    $sfs | ForEach-Object {
        
        [SfProject]$context = $_

        _update-lastGetLatest $context

        $branch = tfs-get-branchPath $context.webAppPath
        if ($branch) {
            $context.branch = $branch
            _sfData-save-project $context
        }
    }
}

function _update-lastGetLatest {
    param (
        [SfProject]$context
    )
    
    $lastGetLatestTfs = _get-lastWorkspaceChangesetDate $context
    if ($lastGetLatestTfs) {
        if ($context.lastGetLatest) {
            $lastGetLatestTool = [datetime]::Parse($context.lastGetLatest)
            
            # only update if not get-latest issued already from this tool later than what is in workspace
            if ($lastGetLatestTool -lt $lastGetLatestTfs) {
                $context.lastGetLatest = $lastGetLatestTfs
                _sfData-save-project $context
            }
        }
        else {
            $context.lastGetLatest = $lastGetLatestTfs
            _sfData-save-project $context
        }
    }
}

function _get-lastWorkspaceChangesetDate ([SfProject]$context) {
    if (-not $context) {
        [SfProject]$context = _get-selectedProject
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
