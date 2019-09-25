<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function Undo-PendingChanges {
    
    Param()

    $context = Get-CurrentProject
    if (!$context.branch) {
        return
    }
    
    if (!(Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }

    tfs-undo-pendingChanges $context.solutionPath
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function Show-PendingChanges {
    
    Param(
        [switch]$detailed
        )

    if ($detailed) {
        $format = "Detailed"
    } else {
        $format = "Brief"
    }

    $context = Get-CurrentProject
    if (!$context.branch) {
        return
    }

    if (-not $context -or -not $context.solutionPath -or -not (Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }
    
    $workspaceName = tfs-get-workspaceName $context.solutionPath
    tfs-show-pendingChanges $workspaceName $format
}

function Get-HasPendingChanges {
    $pendingResult = Show-PendingChanges
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
function Get-LatestChanges {
    
    Param(
        [switch]$overwrite
    )
    
    [SfProject]$context = Get-CurrentProject
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
    SaveSelectedProject $context

    Write-Information "Getting latest changes complete."
}
