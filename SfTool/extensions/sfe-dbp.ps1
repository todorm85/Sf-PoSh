if (-not $sfToolLoaded) {
    . "${PSScriptRoot}\..\sfTool.ps1"
}

$dbpAccountId = "592b1b3d-1528-4a47-a285-b3378ff4359f"
$dbpPort = 4080
$dbpEnv = "uat"

function sf-install-dbp {
    Param($accountId)
    $context = _sf-get-context
    
    if ($accountId) {
        $global:dbpAccountId = $accountId
    }

    $webAppPath = $context.webAppPath
    if (!(Test-Path $webAppPath)) {
        throw "invalid or no WebApp path"
    }

    & "${webAppPath}\..\Builds\DBPModuleSetup\dbp.ps1" -organizationAccountId $dbpAccountId -port $dbpPort -environment $dbpEnv
}

function sf-uninstall-dbp {

    $context = _sf-get-context
    $webAppPath = $context.webAppPath
    if (!(Test-Path $webAppPath)) {
        throw "invalid or no solution path"
    }

    & "${webAppPath}\..\Builds\DBPModuleSetup\dbp.ps1" -organizationAccountId ${dbpAccountId} -port ${dbpPort} -environment ${dbpEnv} -rollback $true
}

function sf-reset-appDbp {
    $context = _sf-get-context

    $oldConfigStorageSettings = sf-get-storageMode
    sf-set-storageMode -storageMode $oldConfigStorageSettings.StorageMode -restrictionLevel "Default"

    try {
        try {
            Write-Verbose "Removing dbp module..."
            $output = sf-uninstall-dbp
        } catch {
            Write-Warning "Some errors occurred during DBP module uninstall. Message:$output"
        }

        Write-Verbose "Resetting sitefinity web app..."
        try {
            $output = sf-reset-app -start
        } catch {
            Write-Warning "Some errors ocurred during resetting of sitefinity web app... Message: $output"
        }

        try {
            Write-Verbose "Installing dbp module..."
            $output = sf-install-dbp
        } catch {
            Write-Warning "Some errors ocurred during installation of DBP module. $output"
        }

        Write-Verbose "Resetting app threads in IIS..."
        sf-reset-thread

        Write-Verbose "Starting sitefinity..."
        $port = @(iis-get-websitePort $context.websiteName)[0]
        _sf-start-sitefinity -url "http://localhost:$($port)"
    } catch {
        Write-Error "`n`nException: $_.Exception"
    } finally {
        sf-set-storageMode -storageMode $oldConfigStorageSettings.StorageMode -restrictionLevel $oldConfigStorageSettings.RestrictionLevel
    }
}