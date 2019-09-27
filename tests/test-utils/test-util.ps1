$Global:testProjectDisplayName = 'created_from_TFS'
$Global:fromZipProjectName = 'created_from_zip'
function set-testProject {
    # if ($Global:sf_tests_test_project) {
    #     try {
    #         sf-proj-setCurrent -newContext $Global:sf_tests_test_project
    #         return $Global:sf_tests_test_project
    #     }
    #     catch {
    #         Write-Warning "cloned test project corrupted, recreating..."            
    #     }
    # }
    
    [SfProject[]]$allProjects = @(sf-data-getAllProjects -skipInit)
    $proj = $allProjects | where { $_.displayName -eq $Global:testProjectDisplayName }
    if ($proj.Count -eq 0) {
        throw 'Project named e2e_tests not found. Create and initialize one first from TFS.'
    }

    $proj = $proj[0]
    sf-proj-setCurrent -newContext $proj

    # $Global:sf_tests_test_project = $proj
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
    Write-Warning "Cleanup started."
    [SfProject[]]$projects = sf-data-getAllProjects

    foreach ($proj in $projects) {
        sf-proj-remove -context $proj -noPrompt
    }
}
