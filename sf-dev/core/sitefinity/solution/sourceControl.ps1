<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sd-sourceControl-undoPendingChanges {
    
    Param()

    $context = sd-project-getCurrent
    if (!$context.branch) {
        return
    }
    
    if (!(Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }
    
    tfs-undo-PendingChanges $context.solutionPath
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sd-sourceControl-showPendingChanges {
    
    Param(
        [switch]$detailed
        )

    if ($detailed) {
        $format = "Detailed"
    } else {
        $format = "Brief"
    }

    $context = sd-project-getCurrent
    if (!$context.branch) {
        return
    }

    if (-not $context -or -not $context.solutionPath -or -not (Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }
    
    $workspaceName = tfs-get-workspaceName $context.solutionPath
    tfs-show-PendingChanges $workspaceName $format
}

function sd-sourceControl-hasPendingChanges {
    $pendingResult = sd-sourceControl-showPendingChanges
    if ($pendingResult -eq 'There are no pending changes.') {
        return $false
    } else {
        return $true
    }
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sd-sourceControl-getLatestChanges {
    
    Param(
        [switch]$overwrite
    )
    
    [SfProject]$context = sd-project-getCurrent
    if (!$context.branch) {
        return
    }
    
    $solutionPath = $context.solutionPath
    if (!(Test-Path $solutionPath)) {
        throw "invalid or no solution path"
    }

    if ($solutionPath -eq '') {
        throw "Solution path is not set."
    }

    Write-Information "Getting latest changes for path ${solutionPath}."
    if ($overwrite) {
        tfs-get-latestChanges -branchMapPath $solutionPath -overwrite
    } else {
        tfs-get-latestChanges -branchMapPath $solutionPath
    }
    
    $context.lastGetLatest = [System.DateTime]::Today
    _saveSelectedProject $context

    Write-Information "Getting latest changes complete."
}
