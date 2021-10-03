function sf-nlb-newCluster {
    if (!(_nlb-isProjectValidForNlb)) { return }
    [SfProject]$firstNode = sf-PSproject-get
    [SfProject]$secondNode = _nlb-createSecondProject -name "$($firstNode.displayName)_n2"
    
    $nlbNodesUrls = _nlb-getNlbClusterUrls $firstNode $secondNode
    _nlb-setupNode -node $firstNode -urls $nlbNodesUrls
    _nlb-setupNode -node $secondNode -urls $nlbNodesUrls

    $nlbId = _nginx-createNewCluster $firstNode $secondNode
    $nlbEntry = [NlbEntity]::new($nlbId, $firstNode.id)
    _nlbData-add -entry $nlbEntry
    $nlbEntry.ProjectId = $secondNode.id
    _nlbData-add -entry $nlbEntry

    $firstNode.isInitialized = $false
    sf-PSproject-setCurrent $firstNode
    if ($nlbId) {
        sf-states-save (_nlb-getInitialStateName $nlbId)
    }
}

function sf-nlb-removeCluster {
    param(
        [switch]$skipDeleteOtherNodes
    )

    $p = sf-PSproject-get
    if (!$p) {
        throw 'No project selected.'
    }

    if (!(sf-nlb-getStatus).enabled) {
        throw 'No NLB setup.'
    }
    
    $nlbId = $p.nlbId
    sf-nlb-getNodes -excludeCurrent | % { 
        try {
            Run-InProjectScope -project $_ -script { _nlb-unconfigureNlbForProject }
            if (!$skipDeleteOtherNodes) {
                sf-PSproject-remove -project $_ -keepDb -noPrompt
            }
        }
        catch {
            Write-Warning "Erros while removing other nodes. $_"        
        }
    }

    _nlb-unconfigureNlbForProject
    try {
        _s-nginx-removeCluster $nlbId
    }
    catch {
        Write-Warning "Erros while removing cluster config from nginx configs. $_"        
    }
}

function _nlb-unconfigureNlbForProject {
    $p = sf-PSproject-get
    $nlbId = $p.nlbId
    try {
        _nlbData-remove -entry ([NlbEntity]::new($nlbId, $p.id))
    }
    catch {
        Write-Warning "Erros while removing nlbId from data file. $_"
    }

    try {
        sf-config-System-setSslOffload -flag $false
    }
    catch {
        Write-Warning "Erros while setting ssl offload setting in Sitefinity. $_"            
    }

    try {
        sf-config-System-setNlbUrls
    }
    catch {
        Write-Warning "Errors removing configured NLB nodes from Sitefinity settings. $_"        
    }

    try {
        sf-states-remove -name (_nlb-getInitialStateName $nlbId)
    }
    catch {
        Write-Warning "Error removing NLB initial state: $_"        
    }

    sf-config-Web-removeMachineKey
}

function sf-nlb-getStatus {
    $p = sf-PSproject-get
    if (!$p) {
        throw "No project selected."
    }

    $nlbId = $p.nlbId
    if ($nlbId) {
        try {
            $otherNode = sf-nlb-getNodes -excludeCurrent
        }
        catch {
            Write-Warning "No other nodes."            
        }

        try {
            $url = sf-nlb-getUrl
        }
        catch {
            Write-Warning "No nlb url could be constructed."            
        }

        $nodeIds = @($p.id)
        if ($otherNode) {
            $nodeIds += $otherNode.id
        }

        [PScustomObject]@{
            enabled = $true;
            url     = $url;
            nodeIds = $nodeIds
        }
    }
    else {
        [PScustomObject]@{
            enabled = $false;
        }
    }
}

$Global:SfEvents_OnProjectRemoving += {
    $project = sf-PSproject-get -skipValidation
    if ($project.nlbId) {
        Run-InProjectScope $project { sf-nlb-removeCluster -skipDeleteOtherNodes }
    }
}

function _nlb-setupNode ([SfProject]$node, $urls) {
    $previous = sf-PSproject-get
    try {
        sf-PSproject-setCurrent $node
        sf-config-Web-setMachineKey
        sf-config-System-setNlbUrls -urls $urls
        sf-config-System-setSslOffload -flag $true
        sf-iis-appPool-Reset
        sf-app-ensureRunning
    }
    finally {
        sf-PSproject-setCurrent $previous
    }
}

function _nlb-isProjectValidForNlb {
    if (!$global:sf.config.pathToNginxConfig -or !(Test-Path $global:sf.config.pathToNginxConfig)) {
        Write-Warning "Path to nginx config does not exist. Configure it in $($global:sf.config.userConfigPath)"
        return    
    }

    if ((sf-nlb-getStatus).enabled) {
        Write-Warning "Already setup in NLB"
        return $false
    }

    # check if project is initialized
    $dbName = sf-db-getNameFromDataConfig
    $dbServer = sql-get-dbs | ? { $_.name -eq $dbName }
    if (!$dbServer) {
        Write-Warning "Not initialized with db"
        return $false
    }
    
    return $true
}

function _nlb-createSecondProject ($name) {
    sf-PSproject-clone -skipSourceControlMapping -skipDatabaseClone -skipSolutionClone > $null
    sf-PSproject-rename -newName $name > $null
    sf-PSproject-get
}

function _nlb-getNlbClusterUrls {
    param (
        $firstNode,
        $secondNode
    )

    $firstNodeUrl = sf-bindings-getLocalhostUrl -websiteName $firstNode.websiteName
    $secondNodeUrl = sf-bindings-getLocalhostUrl -websiteName $secondNode.websiteName
    @($firstNodeUrl, $secondNodeUrl)
}

function _nlb-getInitialStateName ($nlbId) {
    "nlb_new_$nlbId"
}
