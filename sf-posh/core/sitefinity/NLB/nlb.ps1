function sf-nlb-newClusterFromCurrent {
    if (!(_nlb-isProjectValidForNlb)) { return }
    [SfProject]$firstNode = sf-project-getCurrent
    [SfProject]$secondNode = _nlb-createSecondProject -name "$($firstNode.displayName)_n2"
    
    $nlbNodesUrls = _nlb-getNlbClusterUrls $firstNode $secondNode
    _nlb-setupNode -node $firstNode -urls $nlbNodesUrls
    _nlb-setupNode -node $secondNode -urls $nlbNodesUrls

    _nginx-createNewCluster $firstNode $secondNode
    sf-project-setCurrent $firstNode
    
    $nlbTag = _nlbTags-filterNlbTag $firstNode.tags
    if ($nlbTag) {
        sf-appStates-save $nlbTag
    }

    sf-nginx-reset
}

function sf-nlb-removeCluster {
    $p = sf-project-getCurrent
    if (!$p) {
        throw 'No project selected.'
    }

    if (!(sf-nlb-getStatus).enabled) {
        throw 'No NLB setup.'
    }
    
    try {
        sf-nlb-getOtherNodes | % { sf-project-remove -context $_ -keepDb }
    }
    catch {
        Write-Warning "Erros while removing other nodes. $_"        
    }

    $nlbTag = _nlbTags-filterNlbTag $p.tags
    try {
        _s-nginx-removeCluster $nlbTag
    }
    catch {
        Write-Warning "Erros while removing cluster config from nginx configs. $_"        
    }
    
    sf-projectTags-removeFromCurrent -tagName $nlbTag
    if (sf-app-isInitialized) {
        try {
            sf-configSystem-setSslOffload -flag $false
        }
        catch {
            Write-Warning "Erros while setting ssl offload setting in Sitefinity. $_"            
        }

        try {
            sf-serverCode-run -typeName "SitefinityWebApp.SfDev.Nlb.NlbSetup" -methodName "RemoveAllNodes" > $null
        }
        catch {
            Write-Warning "Errors removing configured NLB nodes from Sitefinity settings. $_"        
        }
    }

    try {
        sf-appStates-remove -stateName $nlbTag
    }
    catch {
        Write-Warning "Error removing NLB initial state: $_"        
    }
}

function sf-nlb-getStatus {
    $p = sf-project-getCurrent
    if (!$p) {
        throw "No project selected."
    }

    $nlbTag = _nlbTags-filterNlbTag $p.tags
    if ($nlbTag) {
        try {
            $otherNode = sf-nlb-getOtherNodes
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
        
        [PScustomObject]@{
            enabled = $true;
            url     = $url;
            nodeIds = @($p.id, $otherNode.id)
        }
    }
    else {
        [PScustomObject]@{
            enabled = $false;
        }
    }
}

function _nlb-setupNode ([SfProject]$node, $urls) {
    $previous = sf-project-getCurrent
    try {
        sf-project-setCurrent $node
        _sf-configWeb-setMachineKey
        sf-serverCode-run -typeName "SitefinityWebApp.SfDev.Nlb.NlbSetup" -methodName "AddNode" -parameters $urls > $null
        sf-configSystem-setSslOffload -flag $true
    }
    finally {
        sf-project-setCurrent $previous
    }
}

function _nlb-isProjectValidForNlb {
    if (!$global:sf.config.pathToNginxConfig -or !(Test-Path $global:sf.config.pathToNginxConfig)) {
        Write-Warning "Path to nginx config does not exist. Configure it in $($global:sf.config.userConfigPath)"
        . "$($global:sf.config.userConfigPath)"
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
    sf-project-clone -skipSourceControlMapping -skipDatabaseClone > $null
    sf-project-rename -newName $name > $null
    sf-project-getCurrent
}

function _nlb-getNlbClusterUrls {
    param (
        $firstNode,
        $secondNode
    )

    $firstNodeUrl = sf-bindings-getLocalhostUrl -websiteName $firstNode.websiteName
    $secondNodeUrl = sf-bindings-getLocalhostUrl -websiteName $secondNode.websiteName
    "$firstNodeUrl,$secondNodeUrl"
}
