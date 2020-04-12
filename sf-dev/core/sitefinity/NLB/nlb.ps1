$Script:nlbCodeDeployment_ResourcesPath = "$PSScriptRoot\resources\sf"
$Script:nlbDeployment_ServerCodePath = "App_Code\sf-dev\nlb"

$Global:SfEvents_OnAfterProjectSelected += { _sd-nlb-serverCodeDeploy }

function _sd-nlb-serverCodeDeploy {
    [SfProject]$p = sd-project-getCurrent
    $src = $Script:nlbCodeDeployment_ResourcesPath
    $trg = "$($p.webAppPath)\$($Script:nlbDeployment_ServerCodePath)"
    if (!(Test-Path -Path $trg)) {
        New-Item -Path $trg -ItemType Directory > $null
    }

    Copy-Item -Path "$src\*" -Destination $trg -Force -Recurse
}

function sd-nlb-setup {
    if (!(_nlb-isProjectValidForNlb)) { return }
    [SfProject]$firstNode = sd-project-getCurrent
    [SfProject]$secondNode = _nlb-createSecondProject -name $firstNode.displayName
    
    $nlbNodesUrls = _nlb-getNlbClusterUrls $firstNode $secondNode
    _nlb-setupNode -node $firstNode -urls $nlbNodesUrls
    _nlb-setupNode -node $secondNode -urls $nlbNodesUrls

    _nginx-createNewCluster $firstNode $secondNode
    sd-project-setCurrent $firstNode
    sd-nginx-reset
}

function sd-nlb-uninstall {
    $p = sd-project-getCurrent
    if (!$p) {
        throw 'No project selected.'
    }

    if (!(sd-nlb-getStatus).enabled) {
        throw 'No NLB setup.'
    }

    sd-nlb-getOtherNodes | sd-project-remove -keepDb
    
    $nlbTag = _nlbTags-filterNlbTag $p.tags
    
    _s-nginx-removeCluster $nlbTag
    
    sd-projectTags-removeFromCurrent -tagName $nlbTag
    _s-nlb-setSslOffloadForCurrentNode -flag $false
    sd-serverCode-run -typeName "SitefinityWebApp.SfDev.Nlb.NlbSetup" -methodName "RemoveAllNodes" > $null
}

function sd-nlb-getOtherNodes {
    [SfProject]$p = sd-project-getCurrent
    if (!$p) {
        throw "No project selected."
    }
    
    $tag = _nlbTags-filterNlbTag $p.tags
    if (!$tag) {
        throw "Project not part of NLB cluster."
    }

    $result = sd-project-getAll | ? tags -Contains $tag | ? id -ne $p.id
    if (!$result) {
        throw "No associated nodes"
    }

    $result
}

function sd-nlb-forAllNodes {
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock]$script
    )

    $p = sd-project-getCurrent
    if (!$p) {
        throw "No project selected."
    }

    Invoke-Command -ScriptBlock $script
    sd-nlb-getOtherNodes | % {
        sd-project-setCurrent $_
        Invoke-Command -ScriptBlock $script
    }

    sd-project-setCurrent $p
}

function sd-nlb-setSslOffloadForAll {
    param (
        [Parameter(Mandatory=$true)]
        [bool]$flag
    )
    
    sd-nlb-forAllNodes {
        _s-nlb-setSslOffloadForCurrentNode -flag $flag
    }
}

function _s-nlb-setSslOffloadForCurrentNode ([bool]$flag = $false) {
    sd-serverCode-run -typeName "SitefinityWebApp.SfDev.Nlb.NlbSetup" -methodName "SetSslOffload" -parameters $flag.ToString() > $null
}


function sd-nlb-getUrl {
    $p = sd-project-getCurrent
    if (!$p) {
        throw "No project selected."
    }

    $nlbTag = _nlbTags-filterNlbTag $p.tags
    if (!$nlbTag) {
        throw "No nlb configured for current project."
    }
    
    _nlbTags-getUrlFromTag $nlbTag
}

function sd-nlb-getStatus {
    $p = sd-project-getCurrent
    if (!$p) {
        throw "No project selected."
    }

    $nlbTag = _nlbTags-filterNlbTag $p.tags
    if ($nlbTag) {
        $otherNode = sd-nlb-getOtherNodes
        $url = sd-nlb-getUrl
        [PScustomObject]@{
            enabled = $true;
            url = $url;
            nodeIds = @($p.id, $otherNode.id)
        }
    }
    else {
        [PScustomObject]@{
            enabled = $false;
        }
    }
}

function sd-nlb-openNlbSite {
    param(
        [switch]$openInSameWindow
    )

    $url = sd-nlb-getUrl
    os-browseUrl -url $url -openInSameWindow:$openInSameWindow 
}

function _s-app-setMachineKey {
    Param(
        $decryption = "AES",
        $decryptionKey = "53847BC18AFFC19E5C1AC792A4733216DAEB54215529A854",
        $validationKey = "DC38A2532B063784F23AEDBE821F733625AD1C05D4718D2E0D55D842DAC207FB8492043E2EE5861BB3C4B0C4742CF73BDA586A70BDDC4FD50209B465A6DBBB3D"
    )

    [SfProject]$project = sd-project-getCurrent
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
    $previous = sd-project-getCurrent
    try {
        sd-project-setCurrent $node
        _s-app-setMachineKey
        sd-serverCode-run -typeName "SitefinityWebApp.SfDev.Nlb.NlbSetup" -methodName "AddNode" -parameters $urls > $null
        _s-nlb-setSslOffloadForCurrentNode -flag $true
    }
    finally {
        sd-project-setCurrent $previous
    }
}

function _nlb-isProjectValidForNlb {
    if (!(Test-Path $global:sf.config.pathToNginxConfig)) {
        Write-Warning "Path to nginx config does not exist. Configure it in $($global:sf.config.userConfigPath)"
        . "$($global:sf.config.userConfigPath)"
        return    
    }

    if ((sd-nlb-getStatus).enabled) {
        Write-Warning "Already setup in NLB"
        return $false
    }

    # check if project is initialized
    $dbName = sd-db-getNameFromDataConfig
    $dbServer = sql-get-dbs | ? { $_.name -eq $dbName }
    if (!$dbServer) {
        Write-Warning "Not initialized with db"
        return $false
    }
    
    return $true
}

function _nlb-createSecondProject ($name) {
    sd-project-clone -skipSourceControlMapping -skipDatabaseClone > $null
    sd-project-rename -newName $name > $null
    sd-project-getCurrent
}

function _nlb-getNlbClusterUrls {
    param (
        $firstNode,
        $secondNode
    )

    $firstNodeUrl = sd-bindings-getLocalhostUrl -websiteName $firstNode.websiteName
    $secondNodeUrl = sd-bindings-getLocalhostUrl -websiteName $secondNode.websiteName
    "$firstNodeUrl,$secondNodeUrl"
}
