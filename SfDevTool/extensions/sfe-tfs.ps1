
<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-undo-pendingChanges {
    [CmdletBinding()]
    Param()

    $context = _sf-get-context
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
function sf-show-pendingChanges {
    [CmdletBinding()]
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

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sf-get-latest {
    [CmdletBinding()]
    Param()
    
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
