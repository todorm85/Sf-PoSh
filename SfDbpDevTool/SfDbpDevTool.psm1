
$dbpAccountId = "02853754-a710-481f-8423-2fa62e45b215"
$dbpPort = 4080
$dbpEnv = "uat"

<#
    .SYNOPSIS
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sfDbp-install-dbp {
    [CmdletBinding()]
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

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sfDbp-uninstall-dbp {
    [CmdletBinding()]
    Param()

    $context = _sf-get-context
    $webAppPath = $context.webAppPath
    if (!(Test-Path $webAppPath)) {
        throw "invalid or no solution path"
    }

    & "${webAppPath}\..\Builds\DBPModuleSetup\dbp.ps1" -organizationAccountId ${dbpAccountId} -port ${dbpPort} -environment ${dbpEnv} -rollback
}

<#
    .SYNOPSIS 
    .DESCRIPTION
    .PARAMETER xxxx
    .OUTPUTS
    None
#>
function sfDbp-reset-appDbp {
    [CmdletBinding()]
    Param()

    $context = _sf-get-context

    $oldConfigStorageSettings = sfDbp-get-storageMode
    sfDbp-set-storageMode -storageMode $oldConfigStorageSettings.StorageMode -restrictionLevel "Default"

    try {
        try {
            Write-Host "Removing dbp module..."
            $output = sfDbp-uninstall-dbp
        } catch {
            Write-Warning "Some errors occurred during DBP module uninstall. Message:$output"
        }

        Write-Host "Resetting sitefinity web app..."
        try {
            $output = sfDbp-reset-app -start
        } catch {
            Write-Warning "Some errors ocurred during resetting of sitefinity web app... Message: $output"
        }

        try {
            Write-Host "Installing dbp module..."
            $output = sfDbp-install-dbp
        } catch {
            Write-Warning "Some errors ocurred during installation of DBP module. $output"
        }

        Write-Host "Resetting app threads in IIS..."
        sf-reset-thread

        Write-Host "Starting sitefinity..."
        $port = @(iis-get-websitePort $context.websiteName)[0]
        _sfDbp-start-sitefinity -url "http://localhost:$($port)"
    } catch {
        Write-Error "`n`nException: $_.Exception"
    } finally {
        sfDbp-set-storageMode -storageMode $oldConfigStorageSettings.StorageMode -restrictionLevel $oldConfigStorageSettings.RestrictionLevel
    }
}

Export-ModuleMember -Function '*'
