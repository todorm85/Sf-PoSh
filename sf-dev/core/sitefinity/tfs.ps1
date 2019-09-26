<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function tfs-undoPendingChanges {
    
    Param()

    $context = proj-getCurrent
    if (!$context.branch) {
        return
    }
    
    if (!(Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }

    tfs-tfs-undoPendingChanges $context.solutionPath
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function tfs-showPendingChanges {
    
    Param(
        [switch]$detailed
        )

    if ($detailed) {
        $format = "Detailed"
    } else {
        $format = "Brief"
    }

    $context = proj-getCurrent
    if (!$context.branch) {
        return
    }

    if (-not $context -or -not $context.solutionPath -or -not (Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }
    
    $workspaceName = tfs-get-workspaceName $context.solutionPath
    tfs-tfs-showPendingChanges $workspaceName $format
}

function tfs-hasPendingChanges {
    $pendingResult = tfs-showPendingChanges
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
function tfs-getLatestChanges {
    
    Param(
        [switch]$overwrite
    )
    
    [SfProject]$context = proj-getCurrent
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
