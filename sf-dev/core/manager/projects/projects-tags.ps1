function sf-add-tagToProject {
    param (
        [string]$tagName
    )
    
    [SfProject]$project = sf-get-currentProject
    if (!$project.tags) {
        $project.tags = $tagName
    }
    else {
        $project.tags += " $tagName"
    }

    _save-selectedProject -context $project
}

function sf-remove-tagFromProject {
    param (
        [string]$tagName
    )
    
    _validate-tag $tagName
    if (!$tagName) {
        throw "Invalid tag name to remove."
    }

    [SfProject]$project = sf-get-currentProject
    if ($project.tags -and $project.tags.Contains($tagName)) {
        $project.tags = $project.tags.Replace($tagName, '').Replace('  ', ' ').Trim()
    }

    _save-selectedProject -context $project
}

function sf-remove-allTagsFromProject {
    [SfProject]$project = sf-get-currentProject
    $project.tags = ''
    _save-selectedProject -context $project
}

function sf-get-allTagsForProject {
    [SfProject]$project = sf-get-currentProject
    return $project.tags
}

function sf-set-defaultTagFilter {
    param (
        $filter
    )

    _sfData-save-defaultTagsFilter -defaultTagsFilter $filter
}

function sf-get-defaultTagFilter {
    return _sfData-get-defaultTagsFilter
}

function _validate-tag {
    param (
        $tagName
    )
    
    if (!$tag -or $tag.StartsWith('-') -or $tag.Contains(' ')) {
        throw "Invalid tag name. Must not contain spaces and start with '-'"
    }
}