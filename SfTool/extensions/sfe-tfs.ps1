if (-not $sfToolLoaded) {
    . "${PSScriptRoot}\..\sfTool.ps1"
}

function sf-undo-pendingChanges {
    $context = _sf-get-context
    if (!(Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }

    tfs-undo-pendingChanges $context.solutionPath
}

function sf-show-pendingChanges {
    Param(
        [switch]$detailed
        )

    if ($detailed) {
        $format = "Detailed"
    } else {
        $format = "Brief"
    }

    $context = _sf-get-context
    $workspaceName = tfs-get-workspaceName $context.webAppPath
    & tf.exe stat /workspace:$workspaceName /format:$($format)
}

function sf-get-latest {
    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

    if ($solutionPath -eq '') {
        throw "Solution path is not set."
    }

    Write-Verbose "Getting latest changes for path ${solutionPath}."
    tfs-get-latestChanges -branchMapPath $solutionPath
    Write-Verbose "Getting latest changes complete."
}
