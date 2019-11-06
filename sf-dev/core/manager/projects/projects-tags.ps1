$tagCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )

    $possibleValues = @('dummy')
    [SfProject[]]$sfs = sf-data-getAllProjects
    $sfs | ForEach-Object {
        $allTags = $_.tags.Split(' ')
        $allTags = $allTags | Where-Object { !$possibleValues.Contains($_) -and $_ }
        $possibleValues += $allTags
    }

    if ($wordToComplete) {
        $possibleValues | Where-Object {
            $_ -like "$wordToComplete*" -and $_ -ne 'dummy'
        }
    }
    else {
        $possibleValues | Where-Object { $_ -ne 'dummy' }
    }
}

$selectFunctionTagCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )
    
    $values = @(Invoke-Command -ScriptBlock $tagCompleter -ArgumentList $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $values += @("+a")
    $values += @("+u")
    $values
}

Register-ArgumentCompleter -CommandName sf-proj-select -ParameterName tagsFilter -ScriptBlock $selectFunctionTagCompleter

function sf-proj-tags-addToCurrent {
    param (
        [string]$tagName
    )

    _validateTag $tagName
    
    [SfProject]$project = sf-proj-getCurrent
    if (!$project.tags) {
        $project.tags = $tagName
    }
    else {
        $project.tags += " $tagName"
    }

    _saveSelectedProject -context $project
}

Register-ArgumentCompleter -CommandName sf-proj-tags-addToCurrent -ParameterName tagName -ScriptBlock $tagCompleter

function sf-proj-tags-removeFromCurrent {
    param (
        [string]$tagName
    )
    
    _validateTag $tagName
    if (!$tagName) {
        throw "Invalid tag name to remove."
    }

    [SfProject]$project = sf-proj-getCurrent
    if ($project.tags -and $project.tags.Contains($tagName)) {
        $project.tags = $project.tags.Replace($tagName, '').Replace('  ', ' ').Trim()
    }

    _saveSelectedProject -context $project
}

Register-ArgumentCompleter -CommandName sf-proj-tags-removeFromCurrent -ParameterName tagName -ScriptBlock $tagCompleter

function sf-proj-tags-removeAllFromCurrent {
    [SfProject]$project = sf-proj-getCurrent
    $project.tags = ''
    _saveSelectedProject -context $project
}

function sf-proj-tags-getAllFromCurrent {
    $project = sf-proj-getCurrent
    return $project.tags
}

function sf-proj-tags-setDefaultFilter {
    param (
        $filter
    )

    _setDefaultTagsFilter -defaultTagsFilter $filter
}

function sf-proj-tags-getDefaultFilter {
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
    
    if ($tagsFilter -eq '+u') {
        $sitefinities = $sitefinities | Where-Object { !$_.tags }
    }
    elseif ($tagsFilter -and $tagsFilter -ne '+a') {
        $includeTags = $tagsFilter.Split(' ') | Where-Object { !$_.StartsWith('-') }
        if ($includeTags.Count -gt 0) {
            $sitefinities = $sitefinities | Where-Object { _checkIfTagged -sitefinity $_ -tags $includeTags }
        }

        $excludeTags = $tagsFilter.Split(' ') | Where-Object { $_.StartsWith('-') } | ForEach-Object { $_.Remove(0, 1) }
        if ($excludeTags.Count -gt 0) {
            $sitefinities = $sitefinities | Where-Object { !(_checkIfTagged -sitefinity $_ -tags $excludeTags) }
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

function _sf-proj-tags-setNewProjectDefaultTags {
    param (
        [SfProject]$project
    )
    
    $tagsFilter = sf-proj-tags-getDefaultFilter
    if (!$tagsFilter) {
        return    
    }

    $includeTags = $tagsFilter.Split(' ') | Where-Object { !$_.StartsWith('-') }
    $includeTags | ForEach-Object { 
        $project.tags += " $_"
    }

    if ($project.tags) {
        $project.tags = $project.tags.Trim();
    }
}