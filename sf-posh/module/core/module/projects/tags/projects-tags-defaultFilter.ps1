$Script:excludeTagPrefix = '_'

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
    return , $filter
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

Register-ArgumentCompleter -CommandName sf-project-tags-addToDefaultFilter -ParameterName tag -ScriptBlock $Global:SfTagFilterCompleter

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

Register-ArgumentCompleter -CommandName sf-project-tags-removeFromDefaultFilter -ParameterName tag -ScriptBlock $Global:SfTagFilterCompleter

<#
    passing '+u' in include tags will take only untagged
    exclude tags take precedence
    exclude tags are prefixed with '_'
 #>
function sf-project-tags-filter {
    param (
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project,
        [string[]]$tagsFilter
    )
    
    process {
        if ($tagsFilter -eq '+u') {
            $project = $project | Where-Object { !$_.tags }
        }
        elseif ($tagsFilter -and $tagsFilter -ne '+a') {
            $includeTags = $tagsFilter | Where-Object { !$_.StartsWith($excludeTagPrefix) -and !$_.StartsWith('+') }
            if ($includeTags.Count -gt 0) {
                $project = $project | Where-Object { _checkIfTagged -sitefinity $_ -tags $includeTags }
            }

            $mandatoryTags = $tagsFilter | Where-Object { $_.StartsWith('+') } | ForEach-Object { $_.Remove(0, 1) }
            if ($mandatoryTags.Count -gt 0) {
                $project = $project | Where-Object { _checkIfTagged -sitefinity $_ -tags $mandatoryTags -mustHaveAll }
            }

            $excludeTags = $tagsFilter | Where-Object { $_.StartsWith($excludeTagPrefix) } | ForEach-Object { $_.Remove(0, 1) }
            if ($excludeTags.Count -gt 0) {
                $project = $project | Where-Object { !(_checkIfTagged -sitefinity $_ -tags $excludeTags) }
            }
        }

        # check is necessary otherwise collection size is wrong
        if ($project) {
            $project
        }
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
