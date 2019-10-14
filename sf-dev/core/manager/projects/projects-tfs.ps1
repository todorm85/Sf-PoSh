
function _createWorkspace ($context, $branch) {
    try {
        # create and map workspace
        Write-Information "Creating workspace..."
        $workspaceName = $context.id
        tfs-create-workspace $workspaceName $context.solutionPath $GLOBAL:Sf.Config.tfsServerName
    }
    catch {
        throw "Could not create workspace $workspaceName in $($context.solutionPath).`n $_"
    }

    try {
        Write-Information "Creating workspace mappings..."
        tfs-create-mappings -branch $branch -branchMapPath $context.solutionPath -workspaceName $workspaceName -server $GLOBAL:Sf.Config.tfsServerName
    }
    catch {
        throw "Could not create mapping $($branch) in $($context.solutionPath) for workspace ${workspaceName}.`n $_"
    }

    try {
        Write-Information "Getting latest workspace changes..."
        tfs-get-latestChanges -branchMapPath $context.solutionPath -overwrite > $null
        $context.branch = $branch
        $context.lastGetLatest = [DateTime]::Today
        _saveSelectedProject $context
    }
    catch {
        throw "Could not get latest workapce changes. $_"
    }
}
