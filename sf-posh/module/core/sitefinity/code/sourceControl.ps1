function sf-source-undoPendingChanges {
    $context = sf-PSproject-get
    if (!$context.branch) {
        return
    }

    if (!(Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }

    # tfs-undo-PendingChanges $context.solutionPath
    throw "Not implemented for git yet!"
}

function sf-source-showPendingChanges {

    Param(
        [switch]$detailed
    )

    if ($detailed) {
        $format = "Detailed"
    }
    else {
        $format = "Brief"
    }

    $context = sf-PSproject-get
    if (!$context.branch) {
        return
    }

    if (-not $context -or -not $context.solutionPath -or -not (Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }

    throw "Not implemented for git yet!"
}

function sf-source-hasPendingChanges {
    param(
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project
    )
    
    process {
        Run-InFunctionAcceptingProjectFromPipeline {
            param($project)
            throw "Not implemented for git yet!"
        }
    }
}

function sf-source-getLatestChanges {

    Param(
        [switch]$overwrite
    )

    throw "Not implemented for git yet!"

    [SfProject]$context = sf-PSproject-get
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
    }
    else {
    }

    $context.lastGetLatest = [System.DateTime]::Now
    sf-PSproject-save $context

    Write-Information "Getting latest changes complete."
}

function sf-source-new {
    param (
        $remotePath,
        $localPath,
        $directoryName
    )

    InLocationScope $localPath {
        Invoke-Expression -Command "git clone $remotePath $directoryName"
    }
}

function InLocationScope {
    param (
        $location,
        $script
    )
    
    if (!(Test-Path $location)) {
        throw "Invalid local path."
    }

    $originalLocation = Get-Location
    Set-Location $location
    try {
        Invoke-Command -ScriptBlock $script
    }
    finally {
        Set-Location $originalLocation
    }

}