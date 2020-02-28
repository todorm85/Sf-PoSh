$Script:excludeTagPrefix = '_'

$Script:tagFilterCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    $prefixes = @($excludeTagPrefix)
    $prefix = "$wordToComplete"[0]
    if ($prefix -notin $prefixes) {
        $prefix = ''
    }

    $possibleValues = @(Invoke-Command -ScriptBlock $Script:tagCompleter -ArgumentList $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)


    $possibleValues | % { "$prefix$_" }
}

$Script:selectFunctionTagCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )
    
    $values = @(Invoke-Command -ScriptBlock $tagFilterCompleter -ArgumentList $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $values += @("+a")
    $values += @("+u")
    $values
}

Register-ArgumentCompleter -CommandName sf-project-select -ParameterName tagsFilter -ScriptBlock $selectFunctionTagCompleter

function sf-project-tags-setDefaultFilter {
    param (
        [string[]]$filter
    )

    _setDefaultTagsFilter -defaultTagsFilter $filter
}

function sf-project-tags-getDefaultFilter {
    [OutputType([string[]])]
    Param()

    $filter = _getDefaultTagsFilter
    return ,$filter
}

function sf-project-tags-addToDefaultFilter {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $tag
    )

    $defaultFilter = sf-project-tags-getDefaultFilter
    $defaultFilter += @($tag)
    sf-project-tags-setDefaultFilter -filter $defaultFilter
}

Register-ArgumentCompleter -CommandName sf-project-tags-addToDefaultFilter -ParameterName tag -ScriptBlock $Script:tagFilterCompleter

function sf-project-tags-removeFromDefaultFilter {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $tag
    )
    
    [string[]]$defaultFilter = sf-project-tags-getDefaultFilter
    $defaultFilter = $defaultFilter -notlike $tag
    sf-project-tags-setDefaultFilter -filter $defaultFilter
}

Register-ArgumentCompleter -CommandName sf-project-tags-removeFromDefaultFilter -ParameterName tag -ScriptBlock $Script:tagFilterCompleter

<#
    passing '+u' in include tags will take only untagged
    exclude tags take precedence
    exclude tags are prefixed with '-'
 #>
 function _filterProjectsByTags {
    param (
        [SfProject[]]$sitefinities,
        [string[]]$tagsFilter
    )
    
    if ($tagsFilter -eq '+u') {
        $sitefinities = $sitefinities | Where-Object { !$_.tags }
    }
    elseif ($tagsFilter -and $tagsFilter -ne '+a') {
        $includeTags = $tagsFilter | Where-Object { !$_.StartsWith($excludeTagPrefix) }
        if ($includeTags.Count -gt 0) {
            $sitefinities = $sitefinities | Where-Object { _checkIfTagged -sitefinity $_ -tags $includeTags }
        }

        $excludeTags = $tagsFilter | Where-Object { $_.StartsWith($excludeTagPrefix) } | ForEach-Object { $_.Remove(0, 1) }
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

    $sfTags = $sitefinity.tags
    foreach ($tagToCheck in $tagsToCheck) {
        if ($sfTags.Contains($tagToCheck)) {
            return $true
        }
    }

    return $false
}

function _tag-setNewProjectDefaultTags {
    param (
        [SfProject]$project
    )
    
    $tagsFilter = sf-project-tags-getDefaultFilter
    if (!$tagsFilter) {
        return    
    }

    $includeTags = $tagsFilter | Where-Object { !$_.StartsWith($excludeTagPrefix) }
    $includeTags | ForEach-Object { 
        $project.tags += @($_)
    }
}

function _validateTag {
    param (
        $tagName
    )
    
    if (!$tagName -or $tagName.StartsWith($excludeTagPrefix) -or $tagName.Contains(' ')) {
        throw "Invalid tag name. Must not contain spaces and start with $excludeTagPrefix"
    }
}
