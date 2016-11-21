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

    & "${webAppPath}\..\Builds\DBPModuleSetup\dbp.ps1"  -organizationAccountId $dbpAccountId -port $dbpPort -environment $dbpEnv -rollback $true
}
