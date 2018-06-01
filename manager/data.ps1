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
        ForEach ($sitefinity in $sitefinities) {
            if ($sitefinity.name -eq $name) {
                $sitefinitiesParent = $data.SelectSingleNode('/data/sitefinities')
                $sitefinitiesParent.RemoveChild($sitefinity)
            }
        }

        $data.Save($script:dataPath) > $null
    }
    catch {
        throw "Error deleting sitefinity from ${dataPath}. Message: $_.Exception.Message"
    }
}

function _sfData-save-project {
    Param($context)

    $data = New-Object XML
    $data.Load($dataPath) > $null
    $sitefinities = $data.data.sitefinities.sitefinity
    ForEach ($sitefinity in $sitefinities) {
        if ($sitefinity.name -eq $context.name) {
            $sitefinityEntry = $sitefinity
            break
        }
    }

    if ($null -eq $sitefinityEntry) {
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
    $sitefinityEntry.SetAttribute("containerName", $context.containerName)

    $data.Save($dataPath) > $null
}

function _sfData-get-allContainers {
    $data = New-Object XML
    $data.Load($script:dataPath)
    return $data.data.containers.container
}

function _sfData-delete-container {
    Param($containerName)
    try {
        $data = New-Object XML
        $data.Load($script:dataPath) > $null
        $entities = $data.data.containers.container
        ForEach ($entity in $entities) {
            if ($entity.name -eq $containerName) {
                $parent = $data.SelectSingleNode('/data/containers')
                $parent.RemoveChild($entity)
            }
        }

        $data.Save($script:dataPath) > $null
    }
    catch {
        throw "Error deleting entity from ${dataPath}. Message: $_.Exception.Message"
    }
}

function _sfData-save-container {
    Param(
        [Parameter(Mandatory = $true)][string]$containerName
    )

    $data = New-Object XML
    $data.Load($dataPath) > $null
    $containers = $data.data.containers.container
    $selectedContainer = $null
    ForEach ($container in $containers) {
        if ($container.name -eq $containerName) {
            $selectedContainer = $container
            break
        }
    }

    if ($null -eq $selectedContainer) {
        $selectedContainer = $data.CreateElement("container");
        $containersRoot = $data.data.containers
        $containersRoot.AppendChild($selectedContainer)
    }

    $selectedContainer.SetAttribute("name", $containerName)

    $data.Save($dataPath) > $null
}

function _sfData-get-defaultContainerName {
    $data = New-Object XML
    $data.Load($dataPath) > $null
    return $data.data.containers.defaultContainerName
}

function _sfData-save-defaultContainer ($name) {
    $data = New-Object XML
    $data.Load($dataPath) > $null
    $data.data.containers.SetAttribute("defaultContainerName", $name)
    $data.Save($dataPath) > $null
}
