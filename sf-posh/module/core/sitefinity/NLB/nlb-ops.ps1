function sf-nlb-getNodes {
    Param(
        [switch]$excludeCurrent
    )
    
    [SfProject]$p = sf-project-get
    if (!$p) {
        throw "No project selected."
    }
    
    $nlbId = $p.nlbId
    if (!$nlbId) {
        throw "Project not part of NLB cluster."
    }

    $projectIds = sf-nlbData-getProjectIds -nlbId $nlbId | ? { $_ -ne $p.id -or !$excludeCurrent }
    sf-project-get -all | ? { $projectIds -Contains $_.id }
}

function sf-nlb-forAllNodes {
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$script,
        [switch]$excludeCurrent
    )

    sf-nlb-getNodes -excludeCurrent:$excludeCurrent | Run-InProjectScope -script $script
}

function sf-nlb-setSslOffloadForAll {
    param ([bool]$flag)
    
    sf-nlb-forAllNodes {
        sf-configSystem-setSslOffload -flag $flag
    }
}

function sf-nlb-overrideOtherNodeConfigs ([switch]$skipWait) {
    [SfProject]$currentNode = sf-project-get
    $srcConfigs = _sf-path-getConfigBasePath $currentNode
    if (!(Test-Path $srcConfigs)) {
        throw "No source config files."
    }

    $srcWebConfig = _sf-path-getWebConfigPath $currentNode
    sf-nlb-getNodes -excludeCurrent | Run-InProjectScope -script {
        $p = sf-project-get
        $trg = _sf-path-getConfigBasePath $p
        if (!(Test-Path $trg)) {
            New-Item $trg -ItemType Directory
        }

        Remove-Item -Path "$trg\*" -Recurse -Force
        Copy-Item "$srcConfigs\*" $trg
        
        $trgWebConfig = _sf-path-getWebConfigPath $p
        Copy-Item $srcWebConfig $trgWebConfig -Force
    }

    sf-nlb-resetAllNodes -skipWait:$skipWait
}

function sf-nlb-resetAllNodes {
    param([switch]$skipWait)
    sf-nlb-forAllNodes {
        sf-iisAppPool-Reset
        if (!$skipWait) {
            sf-app-sendRequestAndEnsureInitialized
        }
    }
}

function sf-nlb-getUrl {
    $p = sf-project-get
    $nlbId = $p.nlbId
    if (!$nlbId) {
        throw "No nlb configured for current project."
    }
    
    $domain = _nginx-getNlbClusterDomain $nlbId
    "https://$($domain)/"
}

function sf-nlb-changeUrl {
    param($hostname)
    $p = sf-project-get
    $nlbId = $p.nlbId
    if (!$nlbId) {
        throw "No nlb configured for current project."
    }
    
    $domain = _nginx-getNlbClusterDomain $nlbId
    try {
        os-hosts-remove -hostname $domain
    }
    catch {
        Write-Warning "Domain not found in hosts file."    
    }
    
    os-hosts-add $hostname
    _nginx-renameNlbClusterDomain $nlbId $hostname
    sf-nginx-reset
}

function sf-nlb-openNlbSite {
    param(
        [switch]$openInSameWindow
    )

    $url = sf-nlb-getUrl
    os-browseUrl -url $url -openInSameWindow:$openInSameWindow 
}

function sf-nlb-getNlbId {
    sf-project-get | % { $_.nlbId }
}

function _nlb-generateDomain {
    param (
        $nlbId
    )

    "$nlbId.sfdev.com"
}
