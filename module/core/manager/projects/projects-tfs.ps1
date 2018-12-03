function sf-update-allProjectsTfsInfo {
    $sfs = _sfData-get-allProjects
    $sfs | ForEach-Object {
        
        [SfProject]$context = $_

        $lastGetLatest = _get-lastGetlatestFromTfs($context)
        if ($lastGetLatest) {
            $context.lastGetLatest = $lastGetLatest
            _sfData-save-project $context
        }

        $branch = tfs-get-branchPath $sitefinity.webAppPath
        if ($branch) {
            $context.branch = $branch
            _sfData-save-project $context
        }
    }
}

function _get-lastGetlatestFromTfs ([SfProject]$context) {
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
