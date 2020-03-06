$Global:testProjectDisplayName = 'created_from_TFS'
$Global:fromZipProjectName = 'created_from_zip'
function set-testProject {
    [SfProject[]]$allProjects = @(sd-project-getAll)
    $proj = $allProjects | Where-Object { $_.displayName -eq $Global:testProjectDisplayName }
    if ($proj.Count -eq 0) {
        throw "Project named $Global:testProjectDisplayName not found. Create and initialize one first from TFS."
    }

    $proj = $proj[0]
    $result = sd-project-setCurrent -newContext $proj

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

function generateRandomName {
    [string]$random = [Guid]::NewGuid().ToString().Replace('-', '_')
    $random = $random.Substring(1)
    "a$random"
}

function initialize-testEnvironment {
    Write-Information "Cleanup started."
    [SfProject[]]$projects = sd-project-getAll

    foreach ($proj in $projects) {
        sd-project-remove -context $proj -noPrompt
    }
}
