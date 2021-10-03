$Script:excludeTagPrefix = '_'

function sf-PSproject-tags-setDefaultFilter {
    param (
        [string[]]$filter
    )

    _setDefaultTagsFilter -defaultTagsFilter $filter
}

function sf-PSproject-tags-getDefaultFilter {
    [OutputType([string[]])]
    Param()

    $filter = _getDefaultTagsFilter
    return , $filter
}

function sf-PSproject-tags-addToDefaultFilter {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $tag
    )

    $defaultFilter = sf-PSproject-tags-getDefaultFilter
    $defaultFilter += @($tag)
    sf-PSproject-tags-setDefaultFilter -filter $defaultFilter
}

Register-ArgumentCompleter -CommandName sf-PSproject-tags-addToDefaultFilter -ParameterName tag -ScriptBlock $Global:SfTagFilterCompleter

function sf-PSproject-tags-removeFromDefaultFilter {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $tag
    )

    [string[]]$defaultFilter = sf-PSproject-tags-getDefaultFilter
    $defaultFilter = $defaultFilter -notlike $tag
    sf-PSproject-tags-setDefaultFilter -filter $defaultFilter
}

Register-ArgumentCompleter -CommandName sf-PSproject-tags-removeFromDefaultFilter -ParameterName tag -ScriptBlock $Global:SfTagFilterCompleter

<#
    passing '+u' in include tags will take only untagged
    exclude tags take precedence
    exclude tags are prefixed with '_'
 #>
function sf-PSproject-tags-filter {
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
