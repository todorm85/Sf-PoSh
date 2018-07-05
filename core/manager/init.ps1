function init-managerContainers() {
    # initialize
    $defaultContainerName = _sfData-get-defaultContainerName
    if ($defaultContainerName -ne '') {
        $script:selectedContainer = _sfData-get-allContainers | Where-Object {$_.name -eq $defaultContainerName}
    }
    else {
        $script:selectedContainer = [PSCustomObject]@{ name = "" }
    }
}

function init-managerData {
    if (!(Test-Path $script:dataPath)) {
        Write-Host "Initializing script data..."
        New-Item -ItemType file -Path $script:dataPath

        # Create The Document
        $XmlWriter = New-Object System.XMl.XmlTextWriter($script:dataPath, $Null)

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
    }
}

"${PSScriptRoot}\load-types.ps1"
init-managerData
init-managerContainers