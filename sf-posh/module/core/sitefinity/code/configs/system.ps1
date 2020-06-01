function sf-configSystem-setSslOffload ([bool]$flag = $false) {
    [xml]$sysConf = sf-config-open -name "System"
    $sslOffloadSettings = sf-config-getOrCreateElement -parent $sysConf.systemConfig -elementName "sslOffloadingSettings"
    $sslOffloadSettings.SetAttribute("EnableSslOffloading", $flag.ToString())
    sf-config-save $sysConf
}

function sf-configSystem-setNlbUrls {
    param (
        [string[]]$urls
    )
    
    [xml]$sysConf = sf-config-open -name "System"
    [System.Xml.XmlElement]$nlbParams = sf-config-getOrCreateElementPath -parent $sysConf.systemConfig -elementPath "loadBalancingConfig,parameters"

    $nlbParams.RemoveAll() > $null
    foreach ($url in $urls) {
        $urlEntry = $sysConf.CreateElement("add")
        $urlEntry.SetAttribute("value", $url)
        $nlbParams.AppendChild($urlEntry) > $null
    }

    sf-config-save $sysConf
}