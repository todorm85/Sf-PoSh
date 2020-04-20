
function sf-nlb-restoreToInitialNlbState {
    [SfProject]$p = sf-project-getCurrent
    if (!$p) {
        throw "No project."
    }

    $nlbTag = _nlbTags-filterNlbTag $p.tags
    if (!$nlbTag) {
        throw "No NLB cluster."
    }

    sf-nlb-restoreAllToState $nlbTag
}

function sf-nlb-restoreAllToState {
    param([Parameter(Mandatory=$true)]$stateName)
    [SfProject]$p = sf-project-getCurrent
    if (!$p) {
        throw "No project."
    }

    $nlbTag = _nlbTags-filterNlbTag $p.tags
    if (!$nlbTag) {
        throw "No NLB cluster."
    }

    try {
        sf-appStates-restore -stateName $nlbTag
    }
    catch {
        throw "Error restoring to initial nlb state. $_"        
    }

    if (sf-app-isInitialized) {
        sf-nlb-overrideOtherNodeConfigs
    }
    else {
        throw "Node did not initialize after state restore."
    }
}

function sf-nlb-getOtherNodes {
    [SfProject]$p = sf-project-getCurrent
    if (!$p) {
        throw "No project selected."
    }
    
    $tag = _nlbTags-filterNlbTag $p.tags
    if (!$tag) {
        throw "Project not part of NLB cluster."
    }

    $result = sf-project-getAll | ? tags -Contains $tag | ? id -ne $p.id
    if (!$result) {
        throw "No associated nodes"
    }

    $result
}

function sf-nlb-forAllNodes {
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$script
    )

    $p = sf-project-getCurrent
    if (!$p) {
        throw "No project selected."
    }

    Invoke-Command -ScriptBlock $script
    sf-nlb-getOtherNodes | % {
        sf-project-setCurrent $_
        Invoke-Command -ScriptBlock $script
    }

    sf-project-setCurrent $p
}

function sf-nlb-setSslOffloadForAll {
    param (
        [Parameter(Mandatory = $true)]
        [bool]$flag
    )
    
    sf-nlb-forAllNodes {
        sf-configSystem-setSslOffload -flag $flag
    }
}

function sf-nlb-overrideOtherNodeConfigs ([switch]$skipWait) {
    [SfProject]$currentNode = sf-project-getCurrent
    $srcConfigs = _sf-path-getConfigBasePath $currentNode
    if (!(Test-Path $srcConfigs)) {
        throw "No source config files."
    }

    $srcWebConfig = _sf-path-getWebConfigPath $currentNode
    sf-nlb-getOtherNodes | % {
        sf-project-setCurrent $_
        $trg = _sf-path-getConfigBasePath $_
        if (!(Test-Path $trg)) {
            New-Item $trg -ItemType Directory
        }

        Remove-Item -Path "$trg\*" -Recurse -Force
        Copy-Item "$srcConfigs\*" $trg
        
        $trgWebConfig = _sf-path-getWebConfigPath $_
        Copy-Item $srcWebConfig $trgWebConfig -Force
    }

    sf-project-setCurrent $currentNode
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
    $p = sf-project-getCurrent
    if (!$p) {
        throw "No project selected."
    }

    $nlbTag = _nlbTags-filterNlbTag $p.tags
    if (!$nlbTag) {
        throw "No nlb configured for current project."
    }
    
    _nlbTags-getUrlFromTag $nlbTag
}

function sf-nlb-openNlbSite {
    param(
        [switch]$openInSameWindow
    )

    $url = sf-nlb-getUrl
    os-browseUrl -url $url -openInSameWindow:$openInSameWindow 
}
