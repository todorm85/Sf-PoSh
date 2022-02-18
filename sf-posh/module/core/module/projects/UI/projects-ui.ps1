$script:defaultProjectPropsToShow = @("displayName", "id")
 
$script:defaultProjectPropsToOrderBy = @("tags", "nlbId")

$Global:SfAdditionalPropsCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )
    
    $possibleValues = [SfProject].GetMembers() | ? MemberType -eq Property | select -ExpandProperty Name
    if ($wordToComplete) {
        $possibleValues = $possibleValues | Where-Object {
            $_ -like "$wordToComplete*"
        }
    }

    $possibleValues
}

function sf-project-select {
    Param(
        # prefix with + for mandatory, prefix with _ to exclude, +u all untagged
        [object[]]$additionalProps,
        [string[]]$tagsFilter,
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
            $props = $props + $additionalProps
        }

        if (!$orderProps) {
            $orderProps = $script:defaultProjectPropsToOrderBy
        }

        $props = _project-mapProperties -props $props -forDisplay
        $orderProps = _project-mapProperties -props $orderProps -forSort

        if (!$tagsFilter) {
            $tagsFilter = sf-project-tags-getDefaultFilter
        }
        
        if (!$projects) {
            $projects = sf-project-get -all | sf-project-tags-filter -tagsFilter $tagsFilter
        }

        if (!$projects) {
            Write-Warning "No projects found. Check if not using default tag filter."
            return
        }
        
        $selectedSitefinity = _proj-promptSelect -sitefinities $projects -propsToShow $props -propsToOrderBy $orderProps
        sf-project-setCurrent $selectedSitefinity
    }
}

Register-ArgumentCompleter -CommandName sf-project-select -ParameterName tagsFilter -ScriptBlock $Global:SfTagFilterCompleter
Register-ArgumentCompleter -CommandName sf-project-select -ParameterName additionalProps -ScriptBlock $Global:SfAdditionalPropsCompleter

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
        $propsToShow = $script:defaultProjectPropsToShow
    }

    if (!$propsToOrderBy) {
        $propsToOrderBy = $script:defaultProjectPropsToOrderBy
    }

    ui-promptItemSelect -items $sitefinities -propsToShow $propsToShow -propsToOrderBy $propsToOrderBy -multipleSelection:$multipleSelect
}
