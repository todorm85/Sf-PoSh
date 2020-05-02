
function _createWorkspace ([SfProject]$context, $branch, [switch]$force) {
    try {
        # create and map workspace
        Write-Information "Creating workspace..."
        $workspaceName = $context.id
        # $foundSpace = tfs-get-workspaces $sf.config.tfsServerName | ? {$_ -eq $workspaceName}
        # if ($foundSpace) {
        #     tfs-delete-workspace -workspaceName $workspaceName -server $sf.config.tfsServerName
        # }

        tfs-create-workspace $workspaceName $context.solutionPath $GLOBAL:sf.Config.tfsServerName
    }
    catch {
        throw "Could not create workspace $workspaceName in $($context.solutionPath).`n $_"
    }

    try {
        Write-Information "Creating workspace mappings..."
        
        tfs-create-mappings -branch $branch -branchMapPath $context.solutionPath -workspaceName $workspaceName -server $GLOBAL:sf.Config.tfsServerName
    }
    catch {
        throw "Could not create mapping $($branch) in $($context.solutionPath) for workspace ${workspaceName}.`n $_"
    }

    try {
        Write-Information "Getting latest workspace changes..."
        tfs-get-latestChanges -branchMapPath $context.solutionPath -overwrite > $null
        $context.branch = $branch
        $context.lastGetLatest = [DateTime]::Today
    }
    catch {
        throw "Could not get latest workapce changes. $_"
    }
}

function _updateLastGetLatest {
    param (
        [SfProject]$context
    )

    $lastGetLatestTfs = _getLastWorkspaceChangesetDate $context.solutionPath
    $context.lastGetLatest = $lastGetLatestTfs
}

function _getLastWorkspaceChangesetDate {
    Param(
        $path
    )

    if (-not $path) {
        return
    }

    try {
        #TFS returns only the day. not time
        $changesetInfo = tfs-get-lastWorkspaceChangeset $path
    }
    catch {
        Write-Information "Unable to retrieve latest changeset from workspace, fallback to last time get-latest command was issued in this tool."
    }

    if ($changesetInfo -and $changesetInfo[2]) {
        $hasDate = $changesetInfo[2] -match "^.+ (?<date>\d{1,2}\/\d{1,2}\/\d{4}) .*$"
        if ($hasDate) {
            return [datetime]::Parse($Matches.date)
        }
    }
}
