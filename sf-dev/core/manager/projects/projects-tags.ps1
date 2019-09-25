function Add-TagToProject {
    param (
        [string]$tagName
    )

    validate-tag_ $tagName
    
    [SfProject]$project = Get-CurrentProject
    if (!$project.tags) {
        $project.tags = $tagName
    }
    else {
        $project.tags += " $tagName"
    }

    save-selectedProject_ -context $project
}

function Remove-TagFromProject {
    param (
        [string]$tagName
    )
    
    validate-tag_ $tagName
    if (!$tagName) {
        throw "Invalid tag name to remove."
    }

    [SfProject]$project = Get-CurrentProject
    if ($project.tags -and $project.tags.Contains($tagName)) {
        $project.tags = $project.tags.Replace($tagName, '').Replace('  ', ' ').Trim()
    }

    save-selectedProject_ -context $project
}

function Remove-AllTagsFromProject {
    [SfProject]$project = Get-CurrentProject
    $project.tags = ''
    save-selectedProject_ -context $project
}

function Get-AllTagsForProject {
    [SfProject]$project = Get-CurrentProject
    return $project.tags
}

function Set-DefaultTagFilter {
    param (
        $filter
    )

    set-defaultTagsFilter_ -defaultTagsFilter $filter
}

function Get-DefaultTagFilter {
    return get-defaultTagsFilter_
}

function validate-tag_ {
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
 function filter-projectsByTags_ {
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
            $sitefinities = $sitefinities | where { check-ifTagged_ -sitefinity $_ -tags $includeTags }
        }

        $excludeTags = $tagsFilter.Split(' ') | where { $_.StartsWith('-') } | %  { $_.Remove(0,1)}
        if ($excludeTags.Count -gt 0) {
            $sitefinities = $sitefinities | where { !(check-ifTagged_ -sitefinity $_ -tags $excludeTags) }
        }
    }

    $sitefinities
}

function check-ifTagged_ {
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
