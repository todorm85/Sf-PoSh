function init-managerContainers() {
    $data = New-Object XML
    $data.Load($dataPath) > $null
    $containers = $data.SelectSingleNode("/data/containers")
    if ($null -eq $containers) {
        $containersElement = $data.CreateElement("containers");
        $data.data.AppendChild($containersElement)
        $data.Save($dataPath) > $null
        _sfData-save-defaultContainer ''
    }

    # initialize
    $defaultContainerName = _sfData-get-defaultContainerName
    if (-not [string]::IsNullOrEmpty($defaultContainerName)) {
        $global:selectedContainer = _sfData-get-allContainers | Where-Object {$_.name -eq $defaultContainerName}
    } 
    else {
        $global:selectedContainer = [PSCustomObject]@{
            name = ''
        }
    }
}

function init-managerData {
    if (!(Test-Path $global:dataPath)) {
        Write-Host "Initializing script data..."
        New-Item -ItemType file -Path $global:dataPath

        # Create The Document
        $XmlWriter = New-Object System.XMl.XmlTextWriter($global:dataPath, $Null)

        # Set The Formatting
        $xmlWriter.Formatting = "Indented"
        $xmlWriter.Indentation = "4"

        # Write the XML Decleration
        $xmlWriter.WriteStartDocument()
        $xmlWriter.WriteStartElement("data")
        $xmlWriter.WriteStartElement("sitefinities")
        $xmlWriter.WriteEndElement()
        $xmlWriter.WriteEndElement()
        $xmlWriter.Finalize
        # Finish The Document
        $xmlWriter.Flush()
        $xmlWriter.Close()
        $XmlWriter.Dispose()
    }
}

init-managerData
init-managerContainers
