# IMPORTANT: this is called in daily cleanup
function sf-proj-tools-updateAllProjectsTfsInfo {
    $sfs = sf-data-getAllProjects
    $sfs | ForEach-Object {
        [SfProject]$context = $_
        _initializeProject -project $context
        _updateLastGetLatest $context

        $branch = tfs-get-branchPath $context.solutionPath
        if ($branch) {
            $context.branch = $branch
            _setProjectData $context
        }
    }
}

function _updateLastGetLatest {
    param (
        [SfProject]$context
    )
    
    $lastGetLatestTfs = _getLastWorkspaceChangesetDate $context
    if ($lastGetLatestTfs) {
        if ($context.lastGetLatest) {
            $lastGetLatestTool = [datetime]::Parse($context.lastGetLatest)
            
            # only update if not get-latest issued already from this tool later than what is in workspace
            if ($lastGetLatestTool -lt $lastGetLatestTfs) {
                $context.lastGetLatest = $lastGetLatestTfs
                _setProjectData $context
            }
        }
        else {
            $context.lastGetLatest = $lastGetLatestTfs
            _setProjectData $context
        }
    }
}

function _getLastWorkspaceChangesetDate ([SfProject]$context) {
    if (-not $context) {
        [SfProject]$context = sf-proj-getCurrent
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
