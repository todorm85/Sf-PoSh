$Script:tagCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )

    
    $possibleValues = sf-projectTags-getAll
    if ($wordToComplete) {
        $possibleValues = $possibleValues | Where-Object {
            $_ -like "$($wordToComplete.TrimStart($prefixes))*"
        }
    }
    
    $possibleValues
}

function sf-projectTags-getAll {
    sf-project-getAll | ForEach-Object { $_.tags } | Sort-Object | Get-Unique | Where-Object { $_ }
}

function sf-projectTags-addToCurrent {
    param (
        [string]$tagName
    )

    _validateTag $tagName
    
    [SfProject]$project = sf-project-getCurrent
    if (!$project.tags) {
        $project.tags = @($tagName)
    }
    else {
        $project.tags += @($tagName)
    }

    _saveSelectedProject -context $project
}

Register-ArgumentCompleter -CommandName sf-projectTags-addToCurrent -ParameterName tagName -ScriptBlock $tagCompleter

function sf-projectTags-removeFromCurrent {
    param (
        [string]$tagName
    )
    
    _validateTag $tagName
    if (!$tagName) {
        throw "Invalid tag name to remove."
    }

    [SfProject]$project = sf-project-getCurrent
    if ($project.tags) {
        $newTags = @()
        $project.tags | ? {$_ -ne $tagName } | ForEach-Object {$newTags += @($_)}
        $project.tags = $newTags
    }

    _saveSelectedProject -context $project
}

Register-ArgumentCompleter -CommandName sf-projectTags-removeFromCurrent -ParameterName tagName -ScriptBlock $tagCompleter

function sf-projectTags-removeAllFromCurrent {
    [SfProject]$project = sf-project-getCurrent
    $project.tags = @()
    _saveSelectedProject -context $project
}

function sf-projectTags-getAllFromCurrent {
    $project = sf-project-getCurrent
    return $project.tags
}
