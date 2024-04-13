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
    while ($config.ChildNodes[$i].Name -eq "#comment") {
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

function sf-config-update {
    param (
        $configName,
        $script
    )
    
    $config = sf-config-open -name $configName
    Invoke-Command -ScriptBlock $script -ArgumentList $config
    sf-config-save -config $config
}

function xml-getOrCreateElementPath {
    [OutputType([System.XML.XmlElement])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.XML.XmlElement]
        $root,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$elementPath
    )
    
    process {
        $currentParentElement = $root
        while ($elementPath -and $elementPath -match "(?<attribute>^[\w\.:]+?\[.+?\])|(?<element>^[\w\.:]+?)(\/|$)") {
            $currentQueryPart = if ($Matches["element"]) {$Matches["element"]} else {$Matches["attribute"]}
            
            if ($currentQueryPart.Contains("[@")) {
                $elementName = $currentQueryPart.Split("[@", [stringsplitoptions]::RemoveEmptyEntries)[0]
                $attributeName = $currentQueryPart.Split("[@", [stringsplitoptions]::RemoveEmptyEntries)[1].Split("=", [stringsplitoptions]::RemoveEmptyEntries)[0]
                $attrValue = $currentQueryPart.Split("[@", [stringsplitoptions]::RemoveEmptyEntries)[1].Split("=", [stringsplitoptions]::RemoveEmptyEntries)[1].Trim("]").Trim("'")
                $currentElement = $currentParentElement.SelectSingleNode("$elementName[@$attributeName='$attrValue']")
                if (!$currentElement) {
                    $currentElement = $currentParentElement.OwnerDocument.CreateElement($elementName)
                    $currentElement.SetAttribute($attributeName, $attrValue)
                    $currentParentElement.AppendChild($currentElement) > $null
                }
                
                $currentParentElement = $currentElement
            }
            else {
                $currentElement = $currentParentElement[$currentQueryPart]
                if (!$currentElement) {
                    $currentElement = $currentParentElement.OwnerDocument.CreateElement($currentQueryPart)
                    $currentParentElement.AppendChild($currentElement) > $null
                }
    
                $currentParentElement = $currentElement
            }

            if ($elementPath.Length -eq $currentQueryPart.Length) {
                break;
            }
            else {
                $elementPath = ($elementPath.Substring($currentQueryPart.Length, $elementPath.Length - $currentQueryPart.Length)).Trim('/')
            }
        }

        [System.XML.XmlElement]$currentParentElement
    }
}

function xml-removeElementIfExists {
    param (
        [System.Xml.XmlElement]$rootNode,
        $xPath
    )
    
    $element = $rootNode.SelectSingleNode($xPath)
    if ($element) {
        $element.ParentNode.RemoveChild($element)
    }
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
        throw "Trying to extract Sitefinity version from config $configPath, but it does not exist."
    }

    [xml]$xml = Get-Content $configPath
    $xml."$($configName.ToLower())Config".version
}