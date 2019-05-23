function _sfData-get-allProjects {
    param(
        [switch]$skipInit,
        [string]$tagsFilter
    )
    $data = New-Object XML
    $data.Load($Script:dataPath)
    $sfs = $data.data.sitefinities.sitefinity
    [System.Collections.Generic.List``1[SfProject]]$sitefinities = New-Object System.Collections.Generic.List``1[SfProject]
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

            $sitefinities.Add($clone)
        }
    }

    filter-projectsByTags -sitefinities $sitefinities -tagsFilter $tagsFilter
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
    $data.Load($Script:dataPath) > $null
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
    $sitefinityEntry.SetAttribute("tags", $context.tags)
    $sitefinityEntry.SetAttribute("lastGetLatest", $context.lastGetLatest)

    $data.Save($Script:dataPath) > $null
}

function _sfData-save-defaultTagsFilter {
    param (
        [string]$defaultTagsFilter
    )
    
    $data = New-Object XML
    $data.Load($Script:dataPath) > $null
    $data.data.SetAttribute("defaultTagsFilter", $defaultTagsFilter) > $null
    
    $data.Save($Script:dataPath) > $null
}

function _sfData-get-defaultTagsFilter {
    $data = New-Object XML
    $data.Load($Script:dataPath) > $null
    $data.data.GetAttribute("defaultTagsFilter", $defaultTagsFilter)
}

<#
    passing '+' in include tags will take only untagged
    exclude tags take precedence
    exclude tags are prefixed with '-'
 #>
 function filter-projectsByTags {
    param (
        [SfProject[]]$sitefinities,
        [string]$tagsFilter
    )
    
    if ($tagsFilter -eq '+') {
        $sitefinities = $sitefinities | where {!$_.tags}
    }
    elseif ($tagsFilter) {
        $includeTags = $tagsFilter.Split(' ') | where { !$_.StartsWith('-') }
        if ($includeTags.Count -gt 0) {
            $sitefinities = $sitefinities | where { check-ifTagged -sitefinity $_ -tags $includeTags }
        }

        $excludeTags = $tagsFilter.Split(' ') | where { $_.StartsWith('-') } | %  { $_.Remove(0,1)}
        if ($excludeTags.Count -gt 0) {
            $sitefinities = $sitefinities | where { !(check-ifTagged -sitefinity $_ -tags $excludeTags) }
        }
    }

    $sitefinities
}

function check-ifTagged {
    param (
        [SfProject]$sitefinity,
        [string[]]$tagsToCheck
    )

    if (!$sitefinity.tags) {
        return $false
    }

    $sfTags = $sitefinity.tags.Split(' ')
    foreach ($tagToCheck in $tagsToCheck) {
        if ($sfTags.Contains($tagToCheck)) {
            return $true
        }
    }

    return $false
}
