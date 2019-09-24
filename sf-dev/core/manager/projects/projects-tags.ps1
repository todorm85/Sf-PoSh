function Add-TagToProject {
    param (
        [string]$tagName
    )

    _validate-tag $tagName
    
    [SfProject]$project = Get-CurrentProject
    if (!$project.tags) {
        $project.tags = $tagName
    }
    else {
        $project.tags += " $tagName"
    }

    _save-selectedProject -context $project
}

function Remove-TagFromProject {
    param (
        [string]$tagName
    )
    
    _validate-tag $tagName
    if (!$tagName) {
        throw "Invalid tag name to remove."
    }

    [SfProject]$project = Get-CurrentProject
    if ($project.tags -and $project.tags.Contains($tagName)) {
        $project.tags = $project.tags.Replace($tagName, '').Replace('  ', ' ').Trim()
    }

    _save-selectedProject -context $project
}

function Remove-AllTagsFromProject {
    [SfProject]$project = Get-CurrentProject
    $project.tags = ''
    _save-selectedProject -context $project
}

function Get-AllTagsForProject {
    [SfProject]$project = Get-CurrentProject
    return $project.tags
}

function Set-DefaultTagFilter {
    param (
        $filter
    )

    _sfData-save-defaultTagsFilter -defaultTagsFilter $filter
}

function Get-DefaultTagFilter {
    return _sfData-get-defaultTagsFilter
}

function _validate-tag {
    param (
        $tagName
    )
    
    if (!$tagName -or $tagName.StartsWith('-') -or $tagName.Contains(' ')) {
        throw "Invalid tag name. Must not contain spaces and start with '-'"
    }
}
