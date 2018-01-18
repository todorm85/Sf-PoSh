function _sfData-get-allProjects {
    $data = New-Object XML
    $data.Load($script:dataPath)
    return $data.data.sitefinities.sitefinity
}

function _sfData-delete-project {
    Param($context)
    Write-Host "Updating script databse..."
    $name = $context.name
    try {
        $data = New-Object XML
        $data.Load($script:dataPath) > $null
        $sitefinities = $data.data.sitefinities.sitefinity
        ForEach($sitefinity in $sitefinities) {
            if ($sitefinity.name -eq $name) {
                $sitefinitiesParent = $data.SelectSingleNode('/data/sitefinities')
                $sitefinitiesParent.RemoveChild($sitefinity)
            }
        }

        $data.Save($script:dataPath) > $null
    } catch {
        throw "Error deleting sitefinity from ${dataPath}. Message: $_.Exception.Message"
    }
}

function _sfData-save-project {
    Param($context)

    try {
        $data = New-Object XML
        $data.Load($dataPath) > $null
        $sitefinities = $data.data.sitefinities.sitefinity
        ForEach($sitefinity in $sitefinities) {
            if ($sitefinity.name -eq $context.name) {
                $sitefinityEntry = $sitefinity
                break
            }
        }

        if ($sitefinityEntry -eq $null) {
            $sitefinityEntry = $data.CreateElement("sitefinity");
            $sitefinities = $data.SelectSingleNode('/data/sitefinities')
            $sitefinities.AppendChild($sitefinityEntry)
        }

        $sitefinityEntry.SetAttribute("name", $context.name)
        $sitefinityEntry.SetAttribute("displayName", $context.displayName)
        $sitefinityEntry.SetAttribute("solutionPath", $context.solutionPath)
        $sitefinityEntry.SetAttribute("webAppPath", $context.webAppPath)
        $sitefinityEntry.SetAttribute("websiteName", $context.websiteName)
        $sitefinityEntry.SetAttribute("branch", $context.branch)
        $sitefinityEntry.SetAttribute("description", $context.description)

        $data.Save($dataPath) > $null
    } catch {
        throw "Error creating sitefinity in ${dataPath} database file"
    }
}

function init {
    if (!(Test-Path $script:dataPath)) {
        Write-Host "Initializing script data..."
        New-Item -ItemType file -Path $script:dataPath

        # Create The Document
        $XmlWriter = New-Object System.XMl.XmlTextWriter($script:dataPath,$Null)

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

init