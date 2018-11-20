Param($sfDevEnv)
$global:sfDevEnv = $sfDevEnv

if ($sfDevEnv -eq 'prod') {
    Write-Warning PRODUCTION
    $global:sfDevModule = "C:\sf-dev\sf-dev.psd1";
} else {
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

function global:resetFreeSfs() {
    $scriptBlock = {
        Param([SfProject]$sf)
        # $sf.displayName
        if ($sf.displayName -eq 'free' -and -not $sf.containerName) {
            sf-undo-pendingChanges
            sf-get-latestChanges
            sf-clean-solution -cleanPackages $true
            sf-clear-nugetCache
            sf-reset-app -start -build
        }
    }

    sf-start-allProjectsBatch $scriptBlock
}
