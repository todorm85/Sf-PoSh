. "$PSScriptRoot\load-module.ps1" prod

Import-Module "$PSScriptRoot\backup.psm1"
$logPath = "$home\Desktop\update-free-log.txt"

try {
    clear-nugetCache
}
catch {
    add-toLog "Error clearing nuget cache: $_"
}

try {
    sf-update-allProjectsTfsInfo
}
catch {
    add-toLog "Error updating projects TFS info from TFS: $_"
}

try {
    batchOverwriteProjectsWithLatestFromTfsIfNeeded
}
catch {
    add-toLog "Error with projects batch: $_"
}

function add-toLog ($text) {
    $text | Out-File $logsPath -Append
}

function batchOverwriteProjectsWithLatestFromTfsIfNeeded {
    Param(
        $names = @('free')
    )

    $scriptBlock = {
        Param([SfProject]$sf)
        if ($names.Contains($sf.displayName) -and $sf.lastGetLatest -and $sf.lastGetLatest -lt [System.DateTime]::Today) {
            $shouldReset = $false
            if (sf-get-hasPendingChanges) {
                sf-undo-pendingChanges
                $shouldReset = $true
            }

            $getLatestOutput = sf-get-latestChanges
            if (-not ($getLatestOutput.Contains('All files are up to date.'))) {
                $shouldReset = $true
            }

            if ($shouldReset) {
                sf-clean-solution -cleanPackages $true
                sf-reset-app -start -build -precompile
                sf-new-appState -stateName initial
            }
        }
    }

    sf-start-allProjectsBatch $scriptBlock
}
