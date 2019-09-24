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

    sfData-save-defaultTagsFilter_ -defaultTagsFilter $filter
}

function Get-DefaultTagFilter {
    return sfData-get-defaultTagsFilter_
}

function validate-tag_ {
    param (
        $tagName
    )
    
    if (!$tagName -or $tagName.StartsWith('-') -or $tagName.Contains(' ')) {
        throw "Invalid tag name. Must not contain spaces and start with '-'"
    }
}
