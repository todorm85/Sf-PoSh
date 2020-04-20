function sf-config-open {
    [OutputType([XML])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$name
    )

    if ($name.ToLower() -eq "web") {
        $path = _sf-path-getWebConfigPath        
    }
    else {
        _config-ensureSitefinityConfigCreated $name
        $path = _sf-path-getSitefinityConfigPath -configName $name
    }

    [xml](Get-Content $path)
}

function sf-config-save {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [XML]$config
    )

    $i = 1
    while($config.ChildNodes[$i].Name -eq "#comment") {
        $i++
    }

    $name = $config.ChildNodes[$i].Name
    if ($name -eq "configuration") {
        # web.config
        $path = _sf-path-getWebConfigPath
        Set-ItemProperty $path -name IsReadOnly -value $false > $null
    }
    else {
        $name = $name.Replace("Config", "")
        $path = _sf-path-getSitefinityConfigPath -configName $name
    }

    $config.Save($path) > $null
}

function sf-config-getOrCreateElement {
    [CmdletBinding()]
    [OutputType([System.XML.XmlElement])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.XML.XmlElement]
        $parent,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$elementName
    )
    
    process {
        $el = $parent[$elementName]
        if (!$el) {
            $el = $parent.OwnerDocument.CreateElement($elementName)
            $parent.AppendChild($el) > $null
        }

        [System.XML.XmlElement]$el
    }
}

function sf-config-getOrCreateElementPath {
    [OutputType([System.XML.XmlElement])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.XML.XmlElement]
        $parent,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$elementPath
    )
    
    $elements = $elementPath.Split(',')
    for ($i = 0; $i -lt $elements.Count; $i++) {
        $current = $elements[$i]
        $parent = sf-config-getOrCreateElement -parent $parent -elementName $current
    }

    [System.XML.XmlElement]$parent
}

function _config-ensureSitefinityConfigCreated {
    $path = _sf-path-getSitefinityConfigPath -configName $name
    if (!(Test-Path $path)) {
        $version = _config-getVersion
        $content = "<?xml version=""1.0"" encoding=""utf-8""?>
<$($name.ToLower())Config xmlns:config=""urn:telerik:sitefinity:configuration"" xmlns:type=""urn:telerik:sitefinity:configuration:type"" config:version=""$version""></$($name.ToLower())Config>"
        $content | Out-File $path -Encoding utf8
    }
}

function _config-getVersion ($configName = "Data") {
    $configPath = _sf-path-getSitefinityConfigPath $configName
    if (!(Test-Path $configPath)) {
        throw "Config $configPath does not exist."
    }

    [xml]$xml = Get-Content $configPath
    $xml."$($configName.ToLower())Config".version
}