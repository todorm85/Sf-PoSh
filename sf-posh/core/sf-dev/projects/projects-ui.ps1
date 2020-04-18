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
        [string[]]$tagsFilter
    )

    if (!$tagsFilter) {
        $tagsFilter = sf-projectTags-getDefaultFilter
    }

    [SfProject[]]$sitefinities = @(sf-project-getAll -tagsFilter $tagsFilter)

    if (!$sitefinities[0]) {
        Write-Warning "No projects found. Check if not using default tag filter."
        return
    }

    $selectedSitefinity = _promptProjectSelect -sitefinities $sitefinities
    
    sf-project-setCurrent $selectedSitefinity >> $null
    _verifyDefaultBinding
}

<#
    .SYNOPSIS
    Shows info for selected sitefinity.
#>
function sf-project-show {
    [SfProject]$context = sf-project-getCurrent

    if ($null -eq ($context)) {
        Write-Warning "No project selected"
        return
    }

    $binding = sf-iisSite-getBinding
    $url = ''
    if ($binding) {
        $url = "$($binding.domain):$($binding.port) | "
    }

    try {
        $workspaceName = tfs-get-workspaceName $context.webAppPath
    }
    catch {
        Write-Information "Error getting some details from TFS: $_"
    }

    try {
        $appPool = (Get-Website -Name $context.websiteName).applicationPool
    }
    catch {
        Write-Information "Error getting some details from IIS: $_"
    }

    $bindingsLabel = ""
    if ($context.websiteName) {
        [SiteBinding[]]$bindings = iis-bindings-getAll $context.websiteName
        $bindings | % { $bindingsLabel += " $(_sd-iisSite-buildUrlFromBinding -binding $_)" }
    }

    $otherDetails = @(
        [pscustomobject]@{id = 0; Parameter = "Title"; Value = $context.displayName; },
        [pscustomobject]@{id = 0.5; Parameter = "Id"; Value = $context.id; },

        [pscustomobject]@{id = 0.6; Parameter = " "; Value = " "; },

        [pscustomobject]@{id = 1; Parameter = "Solution path"; Value = $context.solutionPath; },
        [pscustomobject]@{id = 2; Parameter = "Web app path"; Value = $context.webAppPath; },

        [pscustomobject]@{id = 2.5; Parameter = " "; Value = " "; },

        [pscustomobject]@{id = 3; Parameter = "Database Name"; Value = sf-db-getNameFromDataConfig; },

        [pscustomobject]@{id = 3.5; Parameter = " "; Value = " "; },

        [pscustomobject]@{id = 4; Parameter = "Website Name in IIS"; Value = $context.websiteName; },
        [pscustomobject]@{id = 5; Parameter = "Bindings"; Value = $bindingsLabel; },
        [pscustomobject]@{id = 6; Parameter = "Application Pool Name"; Value = $appPool; },

        [pscustomobject]@{id = 6.5; Parameter = " "; Value = " "; },

        [pscustomobject]@{id = 7; Parameter = "TFS workspace name"; Value = $workspaceName; },
        [pscustomobject]@{id = 8; Parameter = "Mapping"; Value = $context.branch; }
        [pscustomobject]@{id = 9; Parameter = "Last get"; Value = $context.GetDaysSinceLastGet(); }
        [pscustomobject]@{id = 10; Parameter = "Tags"; Value = $context.tags }
    )

    $details = $otherDetails | Sort-Object -Property id | Format-Table -Property Parameter, Value -AutoSize -Wrap -HideTableHeaders | Out-String
    Write-Host $details
    Write-Host "Description:`n$($context.description)`n"
}

<#
    .SYNOPSIS
    Shows info for all sitefinities managed by the script.
#>
function sf-project-showAll {
    Param(
        [SfProject[]]$sitefinities
    )

    [System.Collections.ArrayList]$output = @()
    foreach ($sitefinity in $sitefinities) {
        $ports = if ($sitefinity.websiteName) {
            iis-bindings-getAll -siteName $sitefinity.websiteName | Select-Object -ExpandProperty 'port' | Get-Unique
        }
        else {
            ''
        }

        [SfProject]$sitefinity = $sitefinity
        $index = [array]::IndexOf($sitefinities, $sitefinity)
        $branch = if ($sitefinity.branch) { $sitefinity.branch.Split([string[]]("$/CMS/Sitefinity 4.0"), [System.StringSplitOptions]::RemoveEmptyEntries)[0] } else { '' }
        $output.add([pscustomobject]@{
                order   = $index;
                ID      = "$($sitefinity.id)";
                Title   = "$index : $($sitefinity.displayName)";
                Branch  = $branch;
                LastGet = $sitefinity.GetDaysSinceLastGet();
                Ports   = "$ports";
                Tags    = $sitefinity.tags
            }) > $null
    }

    $output | Sort-Object -Property order | Format-Table -Property Title, Id, Branch, LastGet, Ports, Tags | Out-String | ForEach-Object { Write-Host $_ }
}

function _getDaysSinceDate {
    Param(
        [Nullable[DateTime]]$date
    )

    if (!$date) {
        return $null
    }

    [System.TimeSpan]$days = [System.TimeSpan]([System.DateTime]::Today - $date.Date)
    return [math]::Round($days.TotalDays, 0)
}

function _promptPredefinedBranchSelect {
    $branches = @($GLOBAL:sf.Config.predefinedBranches)

    if ($branches.Count -eq 0) {
        $selectedBranch = Read-Host -Prompt 'No predefined branches, enter branch path'
        return $selectedBranch
    }

    $i = 0
    foreach ($branch in $branches) {
        $i++
        Write-Host "[$i] : $branch"
    }

    $i++
    Write-Host "[$i] : custom"

    $selectedBranch = $null
    while (!$selectedBranch) {
        $userInput = Read-Host -Prompt "Select branch"
        $userInput = $userInput -as [int]
        $userInput--
        if ($userInput -gt -1 -and $userInput -lt $branches.Count) {
            $selectedBranch = $branches[$userInput]
        }
        else {
            $selectedBranch = Read-Host -Prompt 'enter branch path: '
        }
    }

    return $selectedBranch
}

function _promptPredefinedBuildPathSelect {
    $paths = @($GLOBAL:sf.Config.predefinedBuildPaths)

    if ($paths.Count -eq 0) {
        $selectedPath = Read-Host -Prompt 'No predefined build paths, enter build path'
        return $selectedPath
    }

    $i = 0
    foreach ($path in $paths) {
        $i++
        Write-Host "[$i] : $path"
    }

    $i++
    Write-Host "[$i] : Custom"

    $selectedPath = $null
    while (!$selectedPath) {
        $userInput = Read-Host -Prompt "Select path"
        $userInput = $userInput -as [int]
        $userInput--
        if ($userInput -gt -1 -and $userInput -lt $paths.Length) {
            $selectedPath = $paths[$userInput]
        }
        else {
            $selectedPath = Read-Host -Prompt 'Enter build path (zip or existing web app):'
        }
    }

    return $selectedPath
}

function _promptProjectSelect {
    param (
        [SfProject[]]$sitefinities
    )

    if (-not $sitefinities) {
        Write-Warning "No sitefinities found. Check if not filtered with default tags."
        return
    }

    $sortedSitefinities = $sitefinities | Sort-Object -Property tags, branch

    sf-project-showAll $sortedSitefinities

    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose sitefinity'
        $selectedSitefinity = $sortedSitefinities[$choice]
        if ($null -ne $selectedSitefinity) {
            break;
        }
    }

    $selectedSitefinity
}

function _proj-promptSourcePathSelect {
    while ($selectFrom -ne 1 -and $selectFrom -ne 2) {
        $selectFrom = Read-Host -Prompt "Create from?`n[1] Branch`n[2] Build`n"
    }

    if ($selectFrom -eq 1) {
        _promptPredefinedBranchSelect
    }
    else {
        _promptPredefinedBuildPathSelect
    }
}

function _proj-promptSfsSelection ([SfProject[]]$sitefinities) {
    sf-project-showAll $sitefinities

    $choices = Read-Host -Prompt 'Choose sitefinities (numbers delemeted by space)'
    $choices = $choices.Split(' ')
    [System.Collections.Generic.List``1[object]]$sfsToDelete = New-Object System.Collections.Generic.List``1[object]
    foreach ($choice in $choices) {
        [SfProject]$selectedSitefinity = $sitefinities[$choice]
        if ($null -eq $selectedSitefinity) {
            Write-Error "Invalid selection $choice"
        }

        $sfsToDelete.Add($selectedSitefinity)
    }

    return $sfsToDelete
}