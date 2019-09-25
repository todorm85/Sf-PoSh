function proj_tags_add {
    param (
        [string]$tagName
    )

    _validateTag $tagName
    
    [SfProject]$project = proj_getCurrent
    if (!$project.tags) {
        $project.tags = $tagName
    }
    else {
        $project.tags += " $tagName"
    }

    _saveSelectedProject -context $project
}

function proj_tags_remove {
    param (
        [string]$tagName
    )
    
    _validateTag $tagName
    if (!$tagName) {
        throw "Invalid tag name to remove."
    }

    [SfProject]$project = proj_getCurrent
    if ($project.tags -and $project.tags.Contains($tagName)) {
        $project.tags = $project.tags.Replace($tagName, '').Replace('  ', ' ').Trim()
    }

    _saveSelectedProject -context $project
}

function proj_tags_removeAll {
    [SfProject]$project = proj_getCurrent
    $project.tags = ''
    _saveSelectedProject -context $project
}

function proj_tags_getAll {
    [SfProject]$project = proj_getCurrent
    return $project.tags
}

function proj_tags_setDefaultFilter {
    param (
        $filter
    )

    _setDefaultTagsFilter -defaultTagsFilter $filter
}

function proj_tags_getDefaultFilter {
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
