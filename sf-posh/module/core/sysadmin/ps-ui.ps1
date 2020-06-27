
function ui-promptItemSelect {
    [OutputType([object])]
    param (
        [object[]]$items,
        [object[]]$propsToShow,
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
        [object[]]$propsToShow
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
            $datas[$i] | Add-Member -MemberType NoteProperty -Name "idx" -Value $i -Force
        }

        if (!$propsToShow) {
            $propsToShow = $datas[0] | Get-Member -MemberType Property | select -ExpandProperty Name
        }
    
        $props = @("idx") + $propsToShow
        $datas | ft -Property $props | Out-String | Write-Host
        for ($i = 0; $i -lt $datas.Count; $i++) {
            $datas[$i].PSObject.Properties.Remove('idx')
        }
    }
}
