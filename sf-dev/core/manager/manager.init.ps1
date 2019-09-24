function init-managerData {
    if (!(Test-Path $GLOBAL:SfDevConfig.dataPath)) {
        Write-Information "Initializing script data..."
        New-Item -ItemType file -Path $GLOBAL:SfDevConfig.dataPath

        # Create The Document
        $XmlWriter = New-Object System.XMl.XmlTextWriter($GLOBAL:SfDevConfig.dataPath, $Null)

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

. "$PSScriptRoot\SfProject.ps1"
init-managerData