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

Register-ArgumentCompleter -CommandName sd-project-select -ParameterName tagsFilter -ScriptBlock $selectFunctionTagCompleter

function sd-projectTags-setDefaultFilter {
    param (
        [string[]]$filter
    )

    _setDefaultTagsFilter -defaultTagsFilter $filter
}

function sd-projectTags-getDefaultFilter {
    [OutputType([string[]])]
    Param()

    $filter = _getDefaultTagsFilter
    return ,$filter
}

function sd-projectTags-addToDefaultFilter {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $tag
    )

    $defaultFilter = sd-projectTags-getDefaultFilter
    $defaultFilter += @($tag)
    sd-projectTags-setDefaultFilter -filter $defaultFilter
}

Register-ArgumentCompleter -CommandName sd-projectTags-addToDefaultFilter -ParameterName tag -ScriptBlock $Script:tagFilterCompleter

function sd-projectTags-removeFromDefaultFilter {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $tag
    )

    [string[]]$defaultFilter = sd-projectTags-getDefaultFilter
    $defaultFilter = $defaultFilter -notlike $tag
    sd-projectTags-setDefaultFilter -filter $defaultFilter
}

Register-ArgumentCompleter -CommandName sd-projectTags-removeFromDefaultFilter -ParameterName tag -ScriptBlock $Script:tagFilterCompleter

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

function _validateTag {
    param (
        $tagName
    )

    if (!$tagName -or $tagName.StartsWith($excludeTagPrefix) -or $tagName.Contains(' ')) {
        throw "Invalid tag name. Must not contain spaces and start with $excludeTagPrefix"
    }
}
