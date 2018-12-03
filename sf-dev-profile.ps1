Param($sfDevEnv)
$global:sfDevEnv = $sfDevEnv

if ($sfDevEnv -eq 'prod') {
    Write-Warning PRODUCTION
    $global:sfDevModule = "C:\sf-dev\sf-dev.psd1";
}
else {
    Write-Warning DEVELOPMENT
    $global:sfDevModule = "E:\sf-dev\module\sf-dev.psd1";
}

function global:reloadSfDevModule {
    if ($global:sfDevModule) {
        Import-Module toko-admin -Force -DisableNameChecking
        Import-Module toko-domains -Force -DisableNameChecking
        Import-Module $global:sfDevModule -Force -DisableNameChecking
    }
}

reloadSfDevModule

function global:reloadSfDevProf() {
    & "$PSScriptRoot\sf-dev-profile.ps1" $global:sfDevEnv
}

function global:startWebTestRunner {
    & "D:\IntegrationTestsRunner\Telerik.WebTestRunner\Telerik.WebTestRunner.Client\bin\Debug\Telerik.WebTestRunner.Client.exe"
}

function global:deploySfDev {
    & "E:\sf-dev\deploy.ps1"
}

function global:cleanProjects {
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('tests', 'dev')]
        [string]
        $environemnt
    )

    $cleanScriptPath = "E:\sf-dev\clean-projects.ps1"
    switch ($environemnt) {
        'tests' { & $cleanScriptPath };
        'dev' { & $cleanScriptPath -idPref "sf_dev_" -projectsDir "E:\dev-sitefinities" -dataPath "E:\dev-sitefinities\db.xml" };
        Default {}
    }
    
}

function global:batchOverwriteProjectsWithLatestFromTfsIfNeeded {
    Param(
        $names = @('free')
    )

    # clear-nugetCache
    # sf-update-allProjectsTfsInfo
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
                sf-reset-app -start -build
                sf-new-appState -stateName initial
            }
        }
    }

    sf-start-allProjectsBatch $scriptBlock
}

function global:batchRebuildAndStart {
    Param(
        $names = @('free')
    )

    $scriptBlock = {
        Param([SfProject]$sf)
        if ($names.Contains($sf.displayName)) {
            sf-clean-solution -cleanPackages $true
            sf-reset-app -start -build
            sf-new-appState -stateName initial
        }
    }   

    sf-start-allProjectsBatch $scriptBlock
}