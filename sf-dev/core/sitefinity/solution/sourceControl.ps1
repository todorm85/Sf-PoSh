<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-sol-source-undoPendingChanges {
    
    Param()

    $context = sf-project-getCurrent
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
function sf-sol-source-showPendingChanges {
    
    Param(
        [switch]$detailed
        )

    if ($detailed) {
        $format = "Detailed"
    } else {
        $format = "Brief"
    }

    $context = sf-project-getCurrent
    if (!$context.branch) {
        return
    }

    if (-not $context -or -not $context.solutionPath -or -not (Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }
    
    $workspaceName = tfs-get-workspaceName $context.solutionPath
    tfs-show-PendingChanges $workspaceName $format
}

function sf-sol-source-hasPendingChanges {
    $pendingResult = sf-sol-source-showPendingChanges
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
function sf-sol-source-getLatestChanges {
    
    Param(
        [switch]$overwrite
    )
    
    [SfProject]$context = sf-project-getCurrent
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
