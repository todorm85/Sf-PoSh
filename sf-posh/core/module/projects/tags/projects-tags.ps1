function sf-tags-getAllAvailable {
    sf-project-getAll | ForEach-Object { $_.tags } | Sort-Object | Get-Unique | Where-Object { $_ }
}

function sf-tags-add {
    param (
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project,
        [string]$tagName
    )
    
    process {
        RunWithValidatedProject {
            _validateTag $tagName
            [SfProject]$project = sf-project-getCurrent
            $project.tags.Add($tagName)
            sf-project-save -context $project
        }
    }
}

function sf-tags-remove {
    param (
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project,
        [string]$tagName,
        [switch]$all
    )

    process {
        RunWithValidatedProject {
            if ($all) {
                $project.tags.Clear()
            }
            else {
                _validateTag $tagName
                if (!$tagName) {
                    throw "Invalid tag name to remove."
                }
                
                if ($project.tags) {
                    $project.tags.Remove($tagName) > $null
                }
            }

            sf-project-save -context $project
        }
    }
}

function sf-tags-get {
    $project = sf-project-getCurrent
    return $project.tags
}
