$Script:tagCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )

    
    $possibleValues = sd-projectTags-getAll
    if ($wordToComplete) {
        $possibleValues = $possibleValues | Where-Object {
            $_ -like "$($wordToComplete.TrimStart($prefixes))*"
        }
    }
    
    $possibleValues
}

function sd-projectTags-getAll {
    sd-project-getAll | ForEach-Object { $_.tags } | Sort-Object | Get-Unique | Where-Object { $_ }
}

function sd-projectTags-addToCurrent {
    param (
        [string]$tagName
    )

    _validateTag $tagName
    
    [SfProject]$project = sd-project-getCurrent
    if (!$project.tags) {
        $project.tags = @($tagName)
    }
    else {
        $project.tags += @($tagName)
    }

    _saveSelectedProject -context $project
}

Register-ArgumentCompleter -CommandName sd-projectTags-addToCurrent -ParameterName tagName -ScriptBlock $tagCompleter

function sd-projectTags-removeFromCurrent {
    param (
        [string]$tagName
    )
    
    _validateTag $tagName
    if (!$tagName) {
        throw "Invalid tag name to remove."
    }

    [SfProject]$project = sd-project-getCurrent
    if ($project.tags) {
        $newTags = @()
        $project.tags | ? {$_ -ne $tagName } | ForEach-Object {$newTags += @($_)}
        $project.tags = $newTags
    }

    _saveSelectedProject -context $project
}

Register-ArgumentCompleter -CommandName sd-projectTags-removeFromCurrent -ParameterName tagName -ScriptBlock $tagCompleter

function sd-projectTags-removeAllFromCurrent {
    [SfProject]$project = sd-project-getCurrent
    $project.tags = @()
    _saveSelectedProject -context $project
}

function sd-projectTags-getAllFromCurrent {
    $project = sd-project-getCurrent
    return $project.tags
}
