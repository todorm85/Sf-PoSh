
function _getSqlBackupStateName {
    param (
        [Parameter(Mandatory = $true)]$stateName
    )

    [SfProject]$context = sf-PSproject-get
    return "$($context.id)_$stateName.bak"
}

function _getSqlCredentials {
    $password = ConvertTo-SecureString $GLOBAL:sf.Config.sqlPass -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($GLOBAL:sf.Config.sqlUser, $password)
    $credential
}
