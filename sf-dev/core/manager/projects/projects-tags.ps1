$Script:tagCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )

    
    $possibleValues = tag-getAll
    if ($wordToComplete) {
        $possibleValues = $possibleValues | Where-Object {
            $_ -like "$($wordToComplete.TrimStart($prefixes))*"
        }
    }
    
    $possibleValues
}

function tag-getAll {
    proj-getAll | ForEach-Object { $_.tags } | Sort-Object | Get-Unique | Where-Object { $_ }
}

function tag-addToCurrent {
    param (
        [string]$tagName
    )

    _validateTag $tagName
    
    [SfProject]$project = proj-getCurrent
    if (!$project.tags) {
        $project.tags = @($tagName)
    }
    else {
        $project.tags += @($tagName)
    }

    _saveSelectedProject -context $project
}

Register-ArgumentCompleter -CommandName tag-addToCurrent -ParameterName tagName -ScriptBlock $tagCompleter

function tag-removeFromCurrent {
    param (
        [string]$tagName
    )
    
    _validateTag $tagName
    if (!$tagName) {
        throw "Invalid tag name to remove."
    }

    [SfProject]$project = proj-getCurrent
    if ($project.tags) {
        $newTags = @()
        $project.tags | ? {$_ -ne $tagName } | ForEach-Object {$newTags += @($_)}
        $project.tags = $newTags
    }

    _saveSelectedProject -context $project
}

Register-ArgumentCompleter -CommandName tag-removeFromCurrent -ParameterName tagName -ScriptBlock $tagCompleter

function tag-removeAllFromCurrent {
    [SfProject]$project = proj-getCurrent
    $project.tags = @()
    _saveSelectedProject -context $project
}

function tag-getAllFromCurrent {
    $project = proj-getCurrent
    return $project.tags
}
