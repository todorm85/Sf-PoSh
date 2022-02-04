$script:defaultProjectPropsToShow = @("id", "version", "branch", "title")
 
$script:defaultProjectPropsToOrderBy = @("nlbId", "tags")

function sf-PSproject-select {
    Param(
        # prefix with + for mandatory, prefix with _ to exclude, +u all untagged
        [string[]]$tagsFilter,
        [object[]]$additionalProps,
        [object[]]$orderProps,
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
        $props = $script:defaultProjectPropsToShow
        if ($additionalProps) {
            $props = $additionalProps + $props
        }

        if (!$orderProps) {
            $orderProps = $script:defaultProjectPropsToOrderBy
        }

        $props = _project-mapProperties -props $props -forDisplay
        $orderProps = _project-mapProperties -props $orderProps -forSort

        if (!$tagsFilter) {
            $tagsFilter = sf-PSproject-tags-getDefaultFilter
        }
        
        if (!$projects) {
            $projects = sf-PSproject-get -all | sf-PSproject-tags-filter -tagsFilter $tagsFilter
        }

        if (!$projects) {
            Write-Warning "No projects found. Check if not using default tag filter."
            return
        }
        
        $selectedSitefinity = _proj-promptSelect -sitefinities $projects -propsToShow $props -propsToOrderBy $orderProps
        sf-PSproject-setCurrent $selectedSitefinity
    }
}

Register-ArgumentCompleter -CommandName sf-PSproject-select -ParameterName tagsFilter -ScriptBlock $Global:SfTagFilterCompleter

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
