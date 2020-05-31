$script:dateFormat = "MM/dd/yyyy HH:mm:ss"

function _data-getAllProjects {
    [OutputType([SfProject[]])]
    $data = New-Object XML
    $data.Load($GLOBAL:sf.Config.dataPath)
    $sfs = $data.data.sitefinities.sitefinity
    if (!$sfs) {
        return
    }

    $sfs | ForEach-Object {
        [Collections.Generic.List[string]]$tags = @()
        if ($_.tags) {
            [Collections.Generic.List[string]]$tags = $_.tags.Split(' ')
        }

        $clone = [SfProject]::new()
        $clone.id = $_.id;
        $clone.description = $_.description;
        $clone.displayName = $_.displayName;
        $clone.webAppPath = $_.webAppPath;
        if (($_.Attributes | ? { $_.Name -eq "branch" })) {
            $clone.branch = $_.branch
        }

        if (($_.Attributes | ? { $_.Name -eq "websiteName" })) {
            $clone.websiteName = $_.websiteName
        }

        if (($_.Attributes | ? { $_.Name -eq "solutionPath" })) {
            $clone.solutionPath = $_.solutionPath
        }

        $lastGetLatest = $null
        if ($_.lastGetLatest) {
            $lastGetLatest = [System.DateTime]::ParseExact($_.lastGetLatest, $script:dateFormat, [System.Globalization.CultureInfo]::InvariantCulture)
        }

        $clone.lastGetLatest = $lastGetLatest;

        $clone.tags = [Collections.Generic.List[string]]$tags;

        if ($_.defaultBinding) {
            $parts = ([string]$_.defaultBinding).Split(':')
            [SiteBinding]$defBinding = @{
                protocol = $parts[0]
                domain   = $parts[1]
                port     = $parts[2]
            }

            if ($defBinding.protocol -and $defBinding.port) {
                $clone.defaultBinding = $defBinding;
            }
        }

        $clone
    }
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
                $sitefinitiesParent.RemoveChild($sitefinity) > $null
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
        $context.tags | Sort-Object | Get-Unique | % { $tags = "$tags $_" }
    }

    $tags = $tags.TrimStart(' ')

    $sitefinityEntry.SetAttribute("id", $context.id)
    $sitefinityEntry.SetAttribute("displayName", $context.displayName)
    $sitefinityEntry.SetAttribute("webAppPath", $context.webAppPath)
    $sitefinityEntry.SetAttribute("description", $context.description)
    $sitefinityEntry.SetAttribute("branch", $context.branch)
    $sitefinityEntry.SetAttribute("websiteName", $context.websiteName)
    $sitefinityEntry.SetAttribute("solutionPath", $context.solutionPath)
    $sitefinityEntry.SetAttribute("lastGetLatest", $context.lastGetLatest.ToString($dateFormat, [System.Globalization.CultureInfo]::InvariantCulture))
    $sitefinityEntry.SetAttribute("tags", $tags)
    if ($context.defaultBinding) {
        $sitefinityEntry.SetAttribute("defaultBinding", "$($context.defaultBinding.protocol):$($context.defaultBinding.domain):$($context.defaultBinding.port)")
    }
    else {
        $sitefinityEntry.SetAttribute("defaultBinding", "")
    }

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

    $data.Save($GLOBAL:sf.Config.dataPath) > $null
}