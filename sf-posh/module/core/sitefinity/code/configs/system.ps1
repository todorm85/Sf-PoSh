function sf-config-System-setSslOffload ([bool]$flag = $false) {
    [xml]$sysConf = sf-config-open -name "System"
    $sslOffloadSettings = xml-getOrCreateElementPath $sysConf.systemConfig "sslOffloadingSettings"
    $sslOffloadSettings.SetAttribute("EnableSslOffloading", $flag.ToString())
    sf-config-save $sysConf
}

function sf-config-System-setNlbUrls {
    param (
        [string[]]$urls
    )
    
    [xml]$sysConf = sf-config-open -name "System"
    [System.Xml.XmlElement]$nlbParams = xml-getOrCreateElementPath $sysConf.systemConfig "//loadBalancingConfig/parameters"

    $nlbParams.RemoveAll() > $null
    foreach ($url in $urls) {
        $urlEntry = $sysConf.CreateElement("add")
        $urlEntry.SetAttribute("value", $url)
        $nlbParams.AppendChild($urlEntry) > $null
    }

    sf-config-save $sysConf
}