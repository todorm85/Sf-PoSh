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

    if (!$sitefinities) {
        Write-Warning "No projects found. Check if not using default tag filter."
        return
    }

    $selectedSitefinity = _proj-promptSelect -sitefinities $sitefinities
    
    sf-project-setCurrent $selectedSitefinity >> $null
    _verifyDefaultBinding
}

function sf-project-getInfo {
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [SfProject]
        $project,
        [switch]$detail
    )

    process {
        RunWithValidatedProject {
            $ports = if ($project.websiteName) {
                iis-bindings-getAll -siteName $project.websiteName | Select-Object -ExpandProperty 'port' | Get-Unique
            }

            $result = [PSCustomObject]@{
                Title   = "$($project.displayName)";
                ID      = "$($project.id)";
                Branch  = $project.branch;
                LastGet = $project.GetDaysSinceLastGet();
                Ports   = "$ports";
                Tags    = $project.tags;
                NlbId   = sf-nlbData-getNlbIds -projectId $project.id;
            }

            if ($detail) {
                $result | `
                    Add-Member -Name DbName -Value sf-db-getNameFromDataConfig -MemberType NoteProperty -PassThru | `
                    Add-Member -Name SiteName -Value $project.websiteName -MemberType NoteProperty -PassThru | `
                    Add-Member -Name AppPath -Value $project.webAppPath -MemberType NoteProperty
            }

            $result
        }    
    }
}

function _proj-promptSelect {
    param (
        [SfProject[]]$sitefinities
    )

    if (-not $sitefinities) {
        Write-Warning "No sitefinities found. Check if not filtered with default tags."
        return
    }

    $sortedSitefinities = $sitefinities | Sort-Object -Property tags, branch

    _project-showAllIndexed -sitefinitie $sitefinities

    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose sitefinity'
        $selectedSitefinity = $sortedSitefinities[$choice]
        if ($null -ne $selectedSitefinity) {
            break;
        }
    }

    $selectedSitefinity
}

function _proj-promptSelectMany ([SfProject[]]$sitefinities) {
    _project-showAllIndexed -sitefinitie $sitefinities

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

<#
    .SYNOPSIS
    Shows info for all sitefinities managed by the script.
#>
function _project-showAllIndexed {
    [CmdletBinding()]
    Param(
        [SfProject[]]$sitefinitie
    )

    $i = 0
    $sitefinitie | sf-project-getInfo | % {
        $_.Title = "$i : $($_.Title)"
        $i++
        if ($_.branch) { $_.branch = $_.branch.Replace("$/CMS/Sitefinity 4.0", "") }
        $_
    } | ft | Out-String | Write-Host
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
