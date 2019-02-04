function stop-allMsbuild {
    try {
        Get-Process msbuild -ErrorAction Stop | Stop-Process -ErrorAction Stop
    }
    catch {
        Write-Warning "MSBUILD stop: $_"
    }
}

function set-testProject {
    Param(
        [switch]$oldest
    )

    $allProjects = @(_sfData-get-allProjects)
    if ($allProjects.Count -gt 0) {
        $i = if ($oldest) {0} else {$allProjects.Count - 1}
        $proj = $allProjects[$i]
        set-currentProject $proj
    }
    else {
        throw "no available projects";
    }

    return $proj
}

function existsInHostsFile {
    param (
        $searchParam
    )
    if (-not $searchParam) {
        throw "Cannot search for empty string in hosts file."
    }

    $found = $false
    $hostsPath = "$($env:windir)\system32\Drivers\etc\hosts"
    Get-Content $hostsPath | % {
        if ($_.Contains($searchParam)) {
            $found = $true 
        }
    }

    return $found
}