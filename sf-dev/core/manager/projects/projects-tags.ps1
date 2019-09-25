function proj_tags_add {
    param (
        [string]$tagName
    )

    ValidateTag $tagName
    
    [SfProject]$project = proj_getCurrent
    if (!$project.tags) {
        $project.tags = $tagName
    }
    else {
        $project.tags += " $tagName"
    }

    SaveSelectedProject -context $project
}

function proj_tags_remove {
    param (
        [string]$tagName
    )
    
    ValidateTag $tagName
    if (!$tagName) {
        throw "Invalid tag name to remove."
    }

    [SfProject]$project = proj_getCurrent
    if ($project.tags -and $project.tags.Contains($tagName)) {
        $project.tags = $project.tags.Replace($tagName, '').Replace('  ', ' ').Trim()
    }

    SaveSelectedProject -context $project
}

function proj_tags_removeAll {
    [SfProject]$project = proj_getCurrent
    $project.tags = ''
    SaveSelectedProject -context $project
}

function proj_tags_getAll {
    [SfProject]$project = proj_getCurrent
    return $project.tags
}

function proj_tags_setDefaultFilter {
    param (
        $filter
    )

    SetDefaultTagsFilter -defaultTagsFilter $filter
}

function proj_tags_getDefaultFilter {
    return GetDefaultTagsFilter
}

function ValidateTag {
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
 function FilterProjectsByTags {
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
            $sitefinities = $sitefinities | where { CheckIfTagged -sitefinity $_ -tags $includeTags }
        }

        $excludeTags = $tagsFilter.Split(' ') | where { $_.StartsWith('-') } | %  { $_.Remove(0,1)}
        if ($excludeTags.Count -gt 0) {
            $sitefinities = $sitefinities | where { !(CheckIfTagged -sitefinity $_ -tags $excludeTags) }
        }
    }

    $sitefinities
}

function CheckIfTagged {
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
