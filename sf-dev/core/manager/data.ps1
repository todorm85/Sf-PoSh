function _sfData-get-allProjects ([switch]$skipInit) {
    $data = New-Object XML
    $data.Load($Script:dataPath)
    $sfs = $data.data.sitefinities.sitefinity
    if ($sfs) {
        $sfs | ForEach-Object {
            if ($_.lastGetLatest) {
                $lastGetLatest = [System.DateTime]::Parse($_.lastGetLatest)
            }
            else {
                $lastGetLatest = $null
            }

            $clone = [SfProject]::new($_.id)
            $clone.branch = $_.branch;
            $clone.containerName = $_.containerName;
            $clone.description = $_.description;
            $clone.displayName = $_.displayName;
            $clone.solutionPath = $_.solutionPath;
            $clone.webAppPath = $_.webAppPath;
            $clone.websiteName = $_.websiteName;
            $clone.tags = $_.tags;
            $clone.lastGetLatest = $lastGetLatest;

            if (!$skipInit) {
                _initialize-project -project $clone -suppressWarnings
            }

            $clone
        }
    }
}

function _sfData-delete-project {
    Param($context)
    Write-Information "Updating script databse..."
    $id = $context.id
    try {
        $data = New-Object XML
        $data.Load($Script:dataPath) > $null
        $sitefinities = $data.data.sitefinities.sitefinity
        ForEach ($sitefinity in $sitefinities) {
            if ($sitefinity.id -eq $id) {
                $sitefinitiesParent = $data.SelectSingleNode('/data/sitefinities')
                $sitefinitiesParent.RemoveChild($sitefinity)
            }
        }

        $data.Save($Script:dataPath) > $null
    }
    catch {
        throw "Error deleting sitefinity from ${dataPath}. Message: $_"
    }
}

function _sfData-save-project {
    Param([SfProject]$context)

    $context = [SfProject]$context
    $data = New-Object XML
    $data.Load($dataPath) > $null
    $sitefinities = $data.data.sitefinities.sitefinity
    ForEach ($sitefinity in $sitefinities) {
        if ($sitefinity.id -eq $context.id) {
            $sitefinityEntry = $sitefinity
            break
        }
    }

    if ($null -eq $sitefinityEntry) {
        $sitefinityEntry = $data.CreateElement("sitefinity");
        $sitefinities = $data.SelectSingleNode('/data/sitefinities')
        $sitefinities.AppendChild($sitefinityEntry) > $null
    }

    $sitefinityEntry.SetAttribute("id", $context.id)
    $sitefinityEntry.SetAttribute("displayName", $context.displayName)
    $sitefinityEntry.SetAttribute("solutionPath", $context.solutionPath)
    $sitefinityEntry.SetAttribute("webAppPath", $context.webAppPath)
    $sitefinityEntry.SetAttribute("websiteName", $context.websiteName)
    $sitefinityEntry.SetAttribute("branch", $context.branch)
    $sitefinityEntry.SetAttribute("description", $context.description)
    $sitefinityEntry.SetAttribute("containerName", $context.containerName)
    $sitefinityEntry.SetAttribute("tags", $context.tags)
    $sitefinityEntry.SetAttribute("lastGetLatest", $context.lastGetLatest)

    $data.Save($dataPath) > $null
}

function _sfData-get-allContainers {
    $data = New-Object XML
    $data.Load($Script:dataPath)
    return $data.data.containers.container
}

function _sfData-delete-container {
    Param($containerName)
    try {
        $data = New-Object XML
        $data.Load($Script:dataPath) > $null
        $entities = $data.data.containers.container
        ForEach ($entity in $entities) {
            if ($entity.name -eq $containerName) {
                $parent = $data.SelectSingleNode('/data/containers')
                $parent.RemoveChild($entity)
            }
        }

        $data.Save($Script:dataPath) > $null
    }
    catch {
        throw "Error deleting entity from ${dataPath}. Message: $_"
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
    $containers = $data.SelectSingleNode("/data/containers")
    $containers.SetAttribute("defaultContainerName", $name)
    $data.Save($dataPath) > $null
}
