function _initManagerData {
    if (!(Test-Path $GLOBAL:Sf.Config.dataPath)) {
        Write-Information "Initializing script data..."
        New-Item -ItemType file -Path $GLOBAL:Sf.Config.dataPath

        # Create The Document
        $XmlWriter = New-Object System.XMl.XmlTextWriter($GLOBAL:Sf.Config.dataPath, $Null)

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

_initManagerData
