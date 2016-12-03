
$dbpAccountId = "592b1b3d-1528-4a47-a285-b3378ff4359f"
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
    $context = _sfDbp-get-context
    
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

    $context = _sfDbp-get-context
    $webAppPath = $context.webAppPath
    if (!(Test-Path $webAppPath)) {
        throw "invalid or no solution path"
    }

    & "${webAppPath}\..\Builds\DBPModuleSetup\dbp.ps1" -organizationAccountId ${dbpAccountId} -port ${dbpPort} -environment ${dbpEnv} -rollback $true
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

    $context = _sfDbp-get-context

    $oldConfigStorageSettings = sfDbp-get-storageMode
    sfDbp-set-storageMode -storageMode $oldConfigStorageSettings.StorageMode -restrictionLevel "Default"

    try {
        try {
            Write-Verbose "Removing dbp module..."
            $output = sfDbp-uninstall-dbp
        } catch {
            Write-Warning "Some errors occurred during DBP module uninstall. Message:$output"
        }

        Write-Verbose "Resetting sitefinity web app..."
        try {
            $output = sfDbp-reset-app -start
        } catch {
            Write-Warning "Some errors ocurred during resetting of sitefinity web app... Message: $output"
        }

        try {
            Write-Verbose "Installing dbp module..."
            $output = sfDbp-install-dbp
        } catch {
            Write-Warning "Some errors ocurred during installation of DBP module. $output"
        }

        Write-Verbose "Resetting app threads in IIS..."
        sfDbp-reset-thread

        Write-Verbose "Starting sitefinity..."
        $port = @(iis-get-websitePort $context.websiteName)[0]
        _sfDbp-start-sitefinity -url "http://localhost:$($port)"
    } catch {
        Write-Error "`n`nException: $_.Exception"
    } finally {
        sfDbp-set-storageMode -storageMode $oldConfigStorageSettings.StorageMode -restrictionLevel $oldConfigStorageSettings.RestrictionLevel
    }
}

Export-ModuleMember -Function '*'
