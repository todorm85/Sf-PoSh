<#
    .SYNOPSIS
    Displays a list of available sitefinities to select from.
    .DESCRIPTION
    Sitefinities that are displayed are displayed by their names. These are sitefinities that were either provisioned or imported by this script.
    .INPUTS
    tagsFilter - Tags in tag filter are delimited by space. If a tag is prefixed with '-' projects tagged with it are excluded. Excluded tags take precedense over included ones.
    If tagsFilter is equal to '+' only untagged projects are shown.
#>
function sf-project-select {
    Param(
        # prefix with + for mandatory, prefix with _ to exclude, +u all untagged
        [string[]]$tagsFilter,
        [object[]]$propsToShow,
        [object[]]$propsToSort,
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project
    )

    begin {
        $projects = @()
    }

    process {
        $projects += $project
    }

    end {
        if (!$tagsFilter) {
            $tagsFilter = sf-tags-getDefaultFilter
        }
        
        if (!$projects) {
            $projects = sf-project-get -all | sf-tags-filter -tagsFilter $tagsFilter
        }

        if (!$projects) {
            Write-Warning "No projects found. Check if not using default tag filter."
            return
        }
        
        $selectedSitefinity = _proj-promptSelect -sitefinities $projects -propsToShow $propsToShow -propsToOrderBy $propsToSort
        sf-project-setCurrent $selectedSitefinity
    }
}

Register-ArgumentCompleter -CommandName sf-project-select -ParameterName tagsFilter -ScriptBlock $Global:SfTagFilterCompleter

function _proj-promptSelect {
    param (
        [SfProject[]]$sitefinities,
        [object[]]$propsToShow,
        [object[]]$propsToOrderBy,
        [switch]$multipleSelect
    )

    if (!$sitefinities) {
        Write-Warning "No sitefinities for selection."
        return
    }

    if (!$propsToShow) {
        $propsToShow = @("displayName", "id", "branchDisplayName", "lastGetLatest", "tags", "nlbId")
    }

    if (!$propsToOrderBy) {
        $propsToOrderBy = @("nlbId", "tags", "branchDisplayName", "displayName")
    }

    ui-promptItemSelect -items $sitefinities -propsToShow $propsToShow -propsToOrderBy $propsToOrderBy -multipleSelection:$multipleSelect
}
