$Global:testProjectDisplayName = 'e2e_tests'


function set-testProject {
    if ($Global:sf_tests_test_project) {
        try {
            set-currentProject -newContext $Global:sf_tests_test_project
            return $Global:sf_tests_test_project
        }
        catch {
            Write-Warning "cloned test project corrupted, recreating..."            
        }
    }

    $intializeTestsEnvResult = initialize-testEnvironment
    
    [SfProject[]]$allProjects = @(sf-get-allProjects)
    $proj = $allProjects | where { $_.displayName -eq $Global:testProjectDisplayName }
    if ($proj.Count -eq 0) {
        throw 'Project named e2e_tests not found. Create and initialize one first.'
    }

    $proj = $proj[0]
    $clonedProjResult = clone-testProject -sourceProj $proj
    $startAppResult = start-app

    $clonedProj = sf-get-currentProject
    $Global:sf_tests_test_project = $clonedProj
    return $clonedProj
}

function clone-testProject ([SfProject]$sourceProj) {
    $sourceName = $sourceProj.displayName
    $tokoAdmin.sql.GetDbs() | Where-Object { $_.name -eq $sourceProj.id } | Should -HaveCount 1

    # edit a file in source project and mark as changed in TFS
    $webConfigPath = "$($sourceProj.webAppPath)\web.config"
    $checkoutOperationResult = tfs-checkout-file $webConfigPath
    [xml]$xmlData = Get-Content $webConfigPath
    [System.Xml.XmlElement]$appSettings = $xmlData.configuration.appSettings
    $newElement = $xmlData.CreateElement("add")
    $testKeyName = generateRandomName
    $newElement.SetAttribute("key", $testKeyName)
    $newElement.SetAttribute("value", "testing")
    $appSettings.AppendChild($newElement)
    $xmlData.Save($webConfigPath) > $null

    sf-clone-project -skipSourceControlMapping -context $sourceProj

    # verify project configuration
    [SfProject]$project = sf-get-currentProject
    $cloneTestName = "$sourceName-clone" # TODO: stop using hardcoded convention here
    $project.displayName | Should -Be $cloneTestName
    $cloneTestId = $project.id
    # $project.branch | Should -Be '$/CMS/Sitefinity 4.0/Code Base'
    # tfs-get-branchPath -path $project.solutionPath | Should -Not -Be $null
    $project.solutionPath.Contains($Script:projectsDirectory) | Should -Be $true
    $project.websiteName | Should -Be $cloneTestId
    
    # verify project artifacts
    Test-Path $project.solutionPath | Should -Be $true
    existsInHostsFile -searchParam $project.displayName | Should -Be $true
    Test-Path "$($project.solutionPath)\$($project.displayName)($($project.id)).sln" | Should -Be $true
    Test-Path "$($project.solutionPath)\Telerik.Sitefinity.sln" | Should -Be $true
    Test-Path "IIS:\AppPools\${cloneTestId}" | Should -Be $true
    Test-Path "IIS:\Sites\${cloneTestId}" | Should -Be $true
    $tokoAdmin.sql.GetDbs() | Where-Object { $_.name -eq $cloneTestId } | Should -HaveCount 1
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
    [SfProject[]]$projects = sf-get-allProjects
    if (!$Global:testProjectDisplayName) {
        Write-Warning "e2e test project name not set, skipping clean."
        return
    }

    foreach ($proj in $projects) {
        if ($proj.displayName -ne $Global:testProjectDisplayName) {
            sf-delete-project -context $proj -noPrompt
        }
    }
}
