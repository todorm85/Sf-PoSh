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
        # DO NOT USE string type as it is converted to empty string not using null
        [string[]]$tagsFilter,
        $titleFilter = $null,
        $branchFilter = $null,
        [object[]]$propsToShow,
        [object[]]$propsToSort
    )

    [SfProject[]]$sitefinities = sf-project-get -all | sf-tags-filter -tagsFilter $tagsFilter
    if (!$sitefinities) {
        Write-Warning "No projects found. Check if not using default tag filter."
        return
    }

    $selectedSitefinity = _proj-promptSelect -sitefinities $sitefinities -propsToShow $propsToShow -propsToOrderBy $propsToSort
    sf-project-setCurrent $selectedSitefinity
}

Register-ArgumentCompleter -CommandName sf-project-select -ParameterName tagsFilter -ScriptBlock {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )

    $values = @(Invoke-Command -ScriptBlock $Script:tagFilterCompleter -ArgumentList $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $values += @("+a")
    $values += @("+u")
    $values
}

function _proj-promptSelect {
    param (
        [SfProject[]]$sitefinities,
        [string[]]$propsToShow,
        [string[]]$propsToOrderBy,
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
