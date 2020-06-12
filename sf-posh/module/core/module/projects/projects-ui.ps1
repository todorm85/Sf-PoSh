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
        $branchFilter = $null
    )

    [SfProject[]]$sitefinities = sf-project-get -all
    if (!$tagsFilter) {
        $tagsFilter = sf-tags-getDefaultFilter
    }

    if ($tagsFilter) {
        $sitefinities = _filterProjectsByTags -sitefinities $sitefinities -tagsFilter $tagsFilter
    }

    if ($null -ne $branchFilter) {
        $sitefinities = $sitefinities | ? branch -Like $branchFilter
    }

    if ($null -ne $titleFilter) {
        $sitefinities = $sitefinities | ? displayName -Like $titleFilter
    }

    if (!$sitefinities) {
        Write-Warning "No projects found. Check if not using default tag filter."
        return
    }

    $selectedSitefinity = _proj-promptSelect -sitefinities $sitefinities
    
    sf-project-setCurrent $selectedSitefinity >> $null
    _verifyDefaultBinding
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

function sf-project-getInfo {
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project,
        [switch]$detail
    )

    process {
        RunWithValidatedProject {
            $ports = if ($project.websiteName) {
                iis-bindings-getAll -siteName $project.websiteName | Select-Object -ExpandProperty 'port' | Get-Unique
            }

            $branch = $project.branch
            if (!$detail -and $branch) {  
                $branch = $branch.Replace("$/CMS/Sitefinity 4.0", "") 
            }

            if ($project.id) {
                $nlbId = sf-nlbData-getNlbIds -projectId $project.id
            }

            $result = [PSCustomObject]@{
                Title   = $project.displayName;
                ID      = $project.id;
                Branch  = $branch;
                LastGet = $project.GetDaysSinceLastGet();
                Ports   = $ports;
                Tags    = $project.tags;
                NlbId   = $nlbId;
            }

            if ($detail) {
                $result | `
                    Add-Member -Name DbName -Value (sf-db-getNameFromDataConfig -context $project) -MemberType NoteProperty -PassThru | `
                    Add-Member -Name SiteName -Value $project.websiteName -MemberType NoteProperty -PassThru | `
                    Add-Member -Name AppPath -Value $project.webAppPath -MemberType NoteProperty
            }

            $result
        } -skipCurrentProjectChange
    }
}

function _proj-promptSelect {
    param (
        [SfProject[]]$sitefinities,
        [string[]]$propsToShow,
        [string[]]$propsToOrderBy,
        [switch]$multipleSelect
    )

    if (!$sitefinities) {
        Write-Warning "No sitefinities found. Check if not filtered with default tags."
        return
    }

    if (!$propsToShow) {
        $propsToShow = @("Title", "ID", "Branch", "LastGet", "Ports", "Tags", "NlbId")
    }

    if (!$propsToOrderBy) {
        $propsToOrderBy = @("NlbId", "Tags", "Branch", "Title")
    }

    $sfInfos = $sitefinities | sf-project-getInfo
    $selection = ui-promptItemSelect -items $sfInfos -propsToShow $propsToShow -propsToOrderBy $propsToOrderBy -multipleSelection:$multipleSelect

    $selection | % {
        $sitefinities | ? id -eq $_.ID
    }
}

function ui-promptItemSelect {
    [OutputType([object])]
    param (
        [object[]]$items,
        [string[]]$propsToShow,
        [string[]]$propsToOrderBy,
        [switch]$multipleSelection
    )
    
    if (!$items) {
        return
    }

    if ($propsToOrderBy) {
        $items = $items | Sort-Object -Property $propsToOrderBy
    }

    _ui-showAllWithIndexedPrefix -datas $items -propsToShow $propsToShow
    while ($true) {
        if ($multipleSelection) {
            $choices = Read-Host -Prompt 'Select items (numbers delemeted by space)'
            $choices = $choices.Split(' ')
            [Collections.Generic.List[object]]$selection = @()
            foreach ($choice in $choices) {
                $currentSelect = $items[$choice]
                if ($null -eq $currentSelect) {
                    Write-Error "Invalid selection $choice"
                }
                else {
                    $selection.Add($currentSelect)
                }
            }

            if ($null -ne $selection) {
                break;
            }
        }
        else {
            [int]$choice = Read-Host -Prompt "Select"
            $selection = $items[$choice]
            if ($null -ne $selection) {
                break;
            }
        }
    }

    $selection
}

function _ui-showAllWithIndexedPrefix {
    param (
        [object[]]$datas,
        [string[]]$propsToShow
    )
    
    if (!$datas) {
        return
    }

    if ($datas[0].GetType().IsValueType -or $datas[0].GetType() -eq "".GetType()) {
        $i = 0
        $datas | % {
            Write-Host "$i : $_"
            $i++
        }
    }
    else {
        for ($i = 0; $i -lt $datas.Count; $i++) {
            $datas[$i] | Add-Member -MemberType NoteProperty -Name "idx" -Value $i
        }

        if (!$propsToShow) {
            $propsToShow = $datas[0] | Get-Member -MemberType Property | select -ExpandProperty Name
        }
    
        $props = @("idx") + $propsToShow
        $datas | ft -Property $props | Out-String | Write-Host
    }
}
