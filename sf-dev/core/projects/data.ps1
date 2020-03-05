function _data-getAllProjects {
    $data = New-Object XML
    $data.Load($GLOBAL:sf.Config.dataPath)
    $sfs = $data.data.sitefinities.sitefinity
    $dataVersion = $data.data.version
    if ($dataVersion -and $script:cachedDataVersion -eq $dataVersion -and $Script:sfsDataCache) {
        return $Script:sfsDataCache
    }
    elseif ($dataVersion) {
        $script:cachedDataVersion = $dataVersion
    }

    [System.Collections.Generic.List``1[SfProject]]$sitefinities = New-Object System.Collections.Generic.List``1[SfProject]
    if ($sfs) {
        $sfs | ForEach-Object {
            $tags = @()
            if ($_.tags) {
                $tags = $_.tags.Split(' ')
            }

            $clone = [SfProject]::new()
            $clone.id = $_.id;
            $clone.description = $_.description;
            $clone.displayName = $_.displayName;
            $clone.webAppPath = $_.webAppPath;
            $clone.tags = $tags;

            if ($_.defaultBinding) {
                $parts = ([string]$_.defaultBinding).Split(':')
                if ($defBinding.protocol -and $defBinding.port) {
                    [SiteBinding]$defBinding = @{
                        protocol = $parts[0]
                        domain   = $parts[1]
                        port     = $parts[2]
                    }

                    $clone.defaultBinding = $defBinding;
                }
            }

            $sitefinities.Add($clone)
        }
    }
    
    $Script:sfsDataCache = $sitefinities
    return $sitefinities
}

function _removeProjectData {
    Param($context)
    Write-Information "Updating script databse..."
    $id = $context.id
    try {
        $data = New-Object XML
        $data.Load($GLOBAL:sf.Config.dataPath) > $null
        $sitefinities = $data.data.sitefinities.sitefinity
        ForEach ($sitefinity in $sitefinities) {
            if ($sitefinity.id -eq $id) {
                $sitefinitiesParent = $data.SelectSingleNode('/data/sitefinities')
                $sitefinitiesParent.RemoveChild($sitefinity)
            }
        }

        _updateData $data
    }
    catch {
        throw "Error deleting sitefinity from ${dataPath}. Message: $_"
    }
}

function _setProjectData {
    Param([SfProject]$context)

    $context = [SfProject]$context
    $data = New-Object XML
    $data.Load($GLOBAL:sf.Config.dataPath) > $null
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

    $tags = ''
    if ($context.tags) {
        $context.tags | % { $tags = "$tags $_" }
    }

    $tags = $tags.TrimStart(' ')

    $sitefinityEntry.SetAttribute("id", $context.id)
    $sitefinityEntry.SetAttribute("displayName", $context.displayName)
    $sitefinityEntry.SetAttribute("webAppPath", $context.webAppPath)
    $sitefinityEntry.SetAttribute("description", $context.description)
    $sitefinityEntry.SetAttribute("tags", $tags)
    $sitefinityEntry.SetAttribute("defaultBinding", "$($context.defaultBinding.protocol):$($context.defaultBinding.domain):$($context.defaultBinding.port)")

    _updateData $data
}

function _setDefaultTagsFilter {
    param (
        [string[]]$defaultTagsFilter
    )
    
    $data = New-Object XML
    $data.Load($GLOBAL:sf.Config.dataPath) > $null
    $serializedFilter = ""
    $defaultTagsFilter | ForEach-Object { $serializedFilter = "$serializedFilter $_" }
    $serializedFilter = $serializedFilter.Trim()
    $data.data.SetAttribute("defaultTagsFilter", $serializedFilter) > $null
    
    _updateData $data
}

function _getDefaultTagsFilter {
    $data = New-Object XML
    $data.Load($GLOBAL:sf.Config.dataPath) > $null
    $result = $data.data.GetAttribute("defaultTagsFilter").Split(" ")
    if ($result) {
        return , $result
    }
    else {
        return @()
    }
}

function _updateData {
    param(
        [XML]$data
    )

    $newVersion = [System.Guid]::NewGuid().ToString()
    $data.data.SetAttribute('version', $newVersion)
    $script:cachedDataVersion = $newVersion
    $Script:sfsDataCache = $null

    $data.Save($GLOBAL:sf.Config.dataPath) > $null
}