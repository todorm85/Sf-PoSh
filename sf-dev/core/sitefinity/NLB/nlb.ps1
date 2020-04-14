$Script:nlbCodeDeployment_ResourcesPath = "$PSScriptRoot\resources\sf"
$Script:nlbDeployment_ServerCodePath = "App_Code\sf-dev\nlb"

$Global:SfEvents_OnAfterProjectInitialized += { _sd-nlb-serverCodeDeployHandler }

function _sd-nlb-serverCodeDeployHandler {
    [SfProject]$p = sf-project-getCurrent
    $src = $Script:nlbCodeDeployment_ResourcesPath
    $trg = "$($p.webAppPath)\$($Script:nlbDeployment_ServerCodePath)"

    _sf-serverCode-deployDirectory $src $trg
}

function sf-nlb-setup {
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

function sf-nlb-uninstall {
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
            _s-nlb-setSslOffloadForCurrentNode -flag $false
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
        _s-nlb-setSslOffloadForCurrentNode -flag $flag
    }
}

function sf-nlb-overrideOtherNodeConfigs ([switch]$skipWait) {
    [SfProject]$currentNode = sf-project-getCurrent
    $srcConfigs = _sf-nlb-getConfigsPath $currentNode
    if (!(Test-Path $srcConfigs)) {
        throw "No source config files."
    }

    $srcWebConfig = _sf-nlb-getWebConfigPath $currentNode
    sf-nlb-getOtherNodes | % {
        sf-project-setCurrent $_
        $trg = _sf-nlb-getConfigsPath $_
        if (!(Test-Path $trg)) {
            New-Item $trg -ItemType Directory
        }

        Remove-Item -Path "$trg\*" -Recurse -Force
        Copy-Item "$srcConfigs\*" $trg
        
        $trgWebConfig = _sf-nlb-getWebConfigPath $_
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

function _sf-nlb-getConfigsPath ([SfProject]$project) {
    "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
}

function _sf-nlb-getWebConfigPath ([SfProject]$project) {
    "$($project.webAppPath)\web.config"
}
function _s-nlb-setSslOffloadForCurrentNode ([bool]$flag = $false) {
    sf-serverCode-run -typeName "SitefinityWebApp.SfDev.Nlb.NlbSetup" -methodName "SetSslOffload" -parameters $flag.ToString() > $null
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

function sf-nlb-openNlbSite {
    param(
        [switch]$openInSameWindow
    )

    $url = sf-nlb-getUrl
    os-browseUrl -url $url -openInSameWindow:$openInSameWindow 
}

function _s-app-setMachineKey {
    Param(
        $decryption = "AES",
        $decryptionKey = "53847BC18AFFC19E5C1AC792A4733216DAEB54215529A854",
        $validationKey = "DC38A2532B063784F23AEDBE821F733625AD1C05D4718D2E0D55D842DAC207FB8492043E2EE5861BB3C4B0C4742CF73BDA586A70BDDC4FD50209B465A6DBBB3D"
    )

    [SfProject]$project = sf-project-getCurrent
    if (!$project) {
        throw "You must select a project to work with first using sf-dev tool."
    }

    $webConfigPath = "$($project.webAppPath)/web.config"
    Set-ItemProperty $webConfigPath -name IsReadOnly -value $false

    [XML]$xmlDoc = Get-Content -Path $webConfigPath

    $systemWeb = $xmlDoc.Configuration["system.web"]
    $machineKey = $systemWeb.machineKey
    if (!$machineKey) {
        $machineKey = $xmlDoc.CreateElement("machineKey") 
        $systemWeb.AppendChild($machineKey) > $null
    }

    $machineKey.SetAttribute("decryption", $decryption)
    $machineKey.SetAttribute("decryptionKey", $decryptionKey)
    $machineKey.SetAttribute("validationKey", $validationKey)
    $xmlDoc.Save($webConfigPath) > $null
}

function _nlb-setupNode ([SfProject]$node, $urls) {
    $previous = sf-project-getCurrent
    try {
        sf-project-setCurrent $node
        _s-app-setMachineKey
        sf-serverCode-run -typeName "SitefinityWebApp.SfDev.Nlb.NlbSetup" -methodName "AddNode" -parameters $urls > $null
        _s-nlb-setSslOffloadForCurrentNode -flag $true
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
