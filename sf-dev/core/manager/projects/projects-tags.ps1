function proj-tags-add {
    param (
        [string]$tagName
    )

    _validateTag $tagName
    
    [SfProject]$project = proj-getCurrent
    if (!$project.tags) {
        $project.tags = $tagName
    }
    else {
        $project.tags += " $tagName"
    }

    _saveSelectedProject -context $project
}

function proj-tags-remove {
    param (
        [string]$tagName
    )
    
    _validateTag $tagName
    if (!$tagName) {
        throw "Invalid tag name to remove."
    }

    [SfProject]$project = proj-getCurrent
    if ($project.tags -and $project.tags.Contains($tagName)) {
        $project.tags = $project.tags.Replace($tagName, '').Replace('  ', ' ').Trim()
    }

    _saveSelectedProject -context $project
}

function proj-tags-removeAll {
    [SfProject]$project = proj-getCurrent
    $project.tags = ''
    _saveSelectedProject -context $project
}

function proj-tags-getAll {
    [SfProject]$project = proj-getCurrent
    return $project.tags
}

function proj-tags-setDefaultFilter {
    param (
        $filter
    )

    _setDefaultTagsFilter -defaultTagsFilter $filter
}

function proj-tags-getDefaultFilter {
    return _getDefaultTagsFilter
}

function _validateTag {
    param (
        $tagName
    )
    
    if (!$tagName -or $tagName.StartsWith('-') -or $tagName.Contains(' ')) {
        throw "Invalid tag name. Must not contain spaces and start with '-'"
    }
}

<#
    passing '+' in include tags will take only untagged
    exclude tags take precedence
    exclude tags are prefixed with '-'
 #>
 function _filterProjectsByTags {
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
            $sitefinities = $sitefinities | where { _checkIfTagged -sitefinity $_ -tags $includeTags }
        }

        $excludeTags = $tagsFilter.Split(' ') | where { $_.StartsWith('-') } | %  { $_.Remove(0,1)}
        if ($excludeTags.Count -gt 0) {
            $sitefinities = $sitefinities | where { !(_checkIfTagged -sitefinity $_ -tags $excludeTags) }
        }
    }

    $sitefinities
}

function _checkIfTagged {
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
