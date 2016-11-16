$dbpAccountId = "1495b382-c205-4ae4-b0e1-204689558b24"
$dbpPort = 4080
$dbpEnv = "uat"

function sf-install-dbp {
    
    $context = _sf-get-context
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
