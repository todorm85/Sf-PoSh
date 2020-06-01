function _initManagerData {
    if (!(Test-Path $GLOBAL:sf.Config.dataPath)) {
        Write-Information "Initializing script data..."
        New-Item -ItemType file -Path $GLOBAL:sf.Config.dataPath

        # Create The Document
        $XmlWriter = New-Object System.XMl.XmlTextWriter($GLOBAL:sf.Config.dataPath, $Null)

        # Set The Formatting
        $xmlWriter.Formatting = "Indented"
        $xmlWriter.Indentation = "4"

        # Write the XML Decleration
        $xmlWriter.WriteStartDocument()
        $xmlWriter.WriteStartElement("data")
        $v = _getLoadedModuleVersion
        if (!$v) {
            throw "Could not detect module version and create sfdev data file."
        }

        $xmlWriter.WriteAttributeString("moduleVersion", $v)
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
