$Global:testProjectDisplayName = 'created_from_TFS'
$Global:fromZipProjectName = 'created_from_zip'
function set-testProject {
    [SfProject[]]$allProjects = @(sf-data-getAllProjects)
    $proj = $allProjects | Where-Object { $_.displayName -eq $Global:testProjectDisplayName }
    if ($proj.Count -eq 0) {
        throw 'Project named e2e_tests not found. Create and initialize one first from TFS.'
    }

    $proj = $proj[0]
    sf-proj-setCurrent -newContext $proj

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
    [SfProject[]]$projects = sf-data-getAllProjects

    foreach ($proj in $projects) {
        sf-proj-remove -context $proj -noPrompt
    }
}
