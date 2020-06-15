function sf-nlb-getNodes {
    Param(
        [switch]$excludeCurrent
    )
    
    [SfProject]$p = sf-project-get
    if (!$p) {
        throw "No project selected."
    }
    
    $nlbId = sf-nlbData-getNlbIds -projectId $p.id
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

    sf-nlb-getNodes -excludeCurrent:$excludeCurrent | InProjectScope $script
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
    sf-nlb-getNodes -excludeCurrent | InProjectScope -script {
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

    if (!$skipWait) {
        sf-nlb-forAllNodes {
            sf-app-sendRequestAndEnsureInitialized
        }
    }
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
    $nlbId = sf-nlbData-getNlbIds $p.id
    if (!$nlbId) {
        throw "No nlb configured for current project."
    }
    
    $domain = _nlb-getDomain $nlbId
    "https://$($domain)/"
}

function sf-nlb-openNlbSite {
    param(
        [switch]$openInSameWindow
    )

    $url = sf-nlb-getUrl
    os-browseUrl -url $url -openInSameWindow:$openInSameWindow 
}

function sf-nlb-getNlbId {
    sf-project-get | % { sf-nlbData-getNlbIds -projectId $_.id }
}

function _nlb-getDomain {
    param (
        $nlbId
    )

    "$nlbId.sfdev.com"
}
