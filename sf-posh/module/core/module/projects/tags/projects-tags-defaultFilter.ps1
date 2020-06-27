$Script:excludeTagPrefix = '_'

function sf-tags-setDefaultFilter {
    param (
        [string[]]$filter
    )

    _setDefaultTagsFilter -defaultTagsFilter $filter
}

function sf-tags-getDefaultFilter {
    [OutputType([string[]])]
    Param()

    $filter = _getDefaultTagsFilter
    return , $filter
}

function sf-tags-addToDefaultFilter {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $tag
    )

    $defaultFilter = sf-tags-getDefaultFilter
    $defaultFilter += @($tag)
    sf-tags-setDefaultFilter -filter $defaultFilter
}

Register-ArgumentCompleter -CommandName sf-tags-addToDefaultFilter -ParameterName tag -ScriptBlock $Script:tagFilterCompleter

function sf-tags-removeFromDefaultFilter {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $tag
    )

    [string[]]$defaultFilter = sf-tags-getDefaultFilter
    $defaultFilter = $defaultFilter -notlike $tag
    sf-tags-setDefaultFilter -filter $defaultFilter
}

Register-ArgumentCompleter -CommandName sf-tags-removeFromDefaultFilter -ParameterName tag -ScriptBlock $Script:tagFilterCompleter

<#
    passing '+u' in include tags will take only untagged
    exclude tags take precedence
    exclude tags are prefixed with '-'
 #>
function sf-tags-filter {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        $sitefinities,
        [string[]]$tagsFilter
    )
    
    process {
        if ($tagsFilter -eq '+u') {
            $sitefinities = $sitefinities | Where-Object { !$_.tags }
        }
        elseif ($tagsFilter) {
            $includeTags = $tagsFilter | Where-Object { !$_.StartsWith($excludeTagPrefix) -and !$_.StartsWith('+') }
            if ($includeTags.Count -gt 0) {
                $sitefinities = $sitefinities | Where-Object { _checkIfTagged -sitefinity $_ -tags $includeTags }
            }

            $mandatoryTags = $tagsFilter | Where-Object { $_.StartsWith('+') } | ForEach-Object { $_.Remove(0, 1) }
            if ($mandatoryTags.Count -gt 0) {
                $sitefinities = $sitefinities | Where-Object { _checkIfTagged -sitefinity $_ -tags $mandatoryTags -mustHaveAll }
            }

            $excludeTags = $tagsFilter | Where-Object { $_.StartsWith($excludeTagPrefix) } | ForEach-Object { $_.Remove(0, 1) }
            if ($excludeTags.Count -gt 0) {
                $sitefinities = $sitefinities | Where-Object { !(_checkIfTagged -sitefinity $_ -tags $excludeTags) }
            }
        }

        $sitefinities
    }
}

function _checkIfTagged {
    param (
        [SfProject]$sitefinity,
        [string[]]$tagsToCheck,
        [switch]$mustHaveAll
    )

    if (!$sitefinity.tags) {
        return $false
    }

    $sfTags = $sitefinity.tags
    foreach ($tagToCheck in $tagsToCheck) {
        if (!$mustHaveAll -and $sfTags.Contains($tagToCheck)) {
            return $true
        }

        if ($mustHaveAll -and !$sfTags.Contains($tagToCheck)) {
            return $false
        }
    }

    return $mustHaveAll
}

function _validateTag {
    param (
        $tagName
    )

    if (!$tagName -or $tagName.StartsWith($excludeTagPrefix) -or $tagName.Contains(' ')) {
        throw "Invalid tag name. Must not contain spaces and start with $excludeTagPrefix"
    }
}
