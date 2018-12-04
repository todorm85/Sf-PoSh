<#
    .SYNOPSIS 
    Displays a list of available sitefinities to select from.
    .DESCRIPTION
    Sitefinities that are displayed are displayed by their names. These are sitefinities that were either provisioned or imported by this script. 
    .OUTPUTS
    None
#>
function sf-select-project {
    [CmdletBinding()]Param(
        [switch]$showUnused
    )
    
    $sitefinities = @(get-allProjectsForCurrentContainer)
    if ($null -eq $sitefinities[0]) {
        Write-Host "No sitefinities in current container! Create one first. sf-create-sitefinity or manually add in sf-data.xml"
        return
    }
    
    if (-not $showUnused) {
        $unusedProjectsName = _get-unusedProjectName
        $sitefinities = $sitefinities | Where-Object { ([SfProject]$_).displayName -ne $unusedProjectsName }
    } else {
        $sitefinities = $sitefinities | Sort-Object -Property @{Expression = "displayName"}, @{Expression = "branch"}
    }

    if (-not $sitefinities) {
        Write-Host "No sitefinities found. Make sure you are showing unused as well or create some."
        return
    }

    sf-show-projects $sitefinities

    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose sitefinity'
        $selectedSitefinity = $sitefinities[$choice]
        if ($null -ne $selectedSitefinity) {
            break;
        }
    }

    if (-not $selectedSitefinity.branch) {
        $branch = tfs-get-branchPath $selectedSitefinity.solutionPath
        if ($branch) {
            $selectedSitefinity.branch = $branch
            _sfData-save-project $selectedSitefinity
        }
    }

    set-currentProject $selectedSitefinity
    
    sf-show-currentProject
}

<#
    .SYNOPSIS 
    Shows info for selected sitefinity.
#>
function sf-show-currentProject ([switch]$detail) {
    [SfProject]$context = _get-selectedProject
    if ($null -eq ($context)) {
        Write-Host "No project selected"
        return
    }

    $ports = @(iis-get-websitePort $context.websiteName)
    $branchShortName = "no branch"
    if ($context.branch) {
        $branchParts = $context.branch.split('/')
        $branchShortName = $branchParts[$branchParts.Count - 1]
    }

    if (-not $detail) {
        Write-Host "$($context.id) | $($context.displayName) | $($branchShortName) | $ports | $(_get-daysSinceLastGetLatest $context)"
        return    
    }
    
    $appPool = @(iis-get-siteAppPool $context.websiteName)
    $workspaceName = tfs-get-workspaceName $context.webAppPath
    $branch = tfs-get-branchPath $context.solutionPath
    $otherDetails = @(
        [pscustomobject]@{id = 0; Parameter = "Title"; Value = $context.displayName; },
        [pscustomobject]@{id = 0.5; Parameter = "Id"; Value = $context.id; },

        [pscustomobject]@{id = 0.6; Parameter = " "; Value = " "; },

        [pscustomobject]@{id = 1; Parameter = "Solution path"; Value = $context.solutionPath; },
        [pscustomobject]@{id = 2; Parameter = "Web app path"; Value = $context.webAppPath; },

        [pscustomobject]@{id = 2.5; Parameter = " "; Value = " "; },
        
        [pscustomobject]@{id = 3; Parameter = "Database Name"; Value = sf-get-appDbName; },
        
        [pscustomobject]@{id = 3.5; Parameter = " "; Value = " "; },

        [pscustomobject]@{id = 4; Parameter = "Website Name in IIS"; Value = $context.websiteName; },
        [pscustomobject]@{id = 5; Parameter = "Ports"; Value = $ports; },
        [pscustomobject]@{id = 6; Parameter = "Application Pool Name"; Value = $appPool; },

        [pscustomobject]@{id = 6.5; Parameter = " "; Value = " "; },

        [pscustomobject]@{id = 7; Parameter = "TFS workspace name"; Value = $workspaceName; },
        [pscustomobject]@{id = 8; Parameter = "Mapping"; Value = $branch; }
        [pscustomobject]@{id = 9; Parameter = "Last get"; Value = _get-daysSinceLastGetLatest $context; }
    )

    $otherDetails | Sort-Object -Property id | Format-Table -Property Parameter, Value -AutoSize -Wrap -HideTableHeaders
    Write-Host "Description:`n$($context.description)`n"
}

<#
    .SYNOPSIS 
    Shows info for all sitefinities managed by the script.
#>
function sf-show-projects {
    Param(
        [SfProject[]]$sitefinities
    )
    
    [System.Collections.ArrayList]$output = @()
    foreach ($sitefinity in $sitefinities) {
        $ports = @(iis-get-websitePort $sitefinity.websiteName)
        [SfProject]$sitefinity = $sitefinity
        $index = [array]::IndexOf($sitefinities, $sitefinity)
        
        $output.add([pscustomobject]@{order = $index; Title = "$index : $($sitefinity.displayName)"; Branch = $sitefinity.branch.split("4.0")[3]; Ports = "$ports"; ID = "$($sitefinity.id)"; LastGet = _get-daysSinceLastGetLatest $sitefinity }) > $null
    }
    $currentContainerName = $Script:selectedContainer.name
    if ($currentContainerName -ne '') {
        Write-Host "`nProjects in $currentContainerName"
    }
    else {
        Write-Host "`nAll projects in no container"
    }

    $output | Sort-Object -Property order | Format-Table -Property Title, Branch, Ports, Id, LastGet | Out-String | ForEach-Object { Write-Host $_ }
}

function _get-daysSinceLastGetLatest ([SfProject]$context) {
    if (-not $context) {
        [SfProject]$context = _get-selectedProject
    }

    if ($context.lastGetLatest) {
        [datetime]$lastGetLatest = [datetime]::Parse($context.lastGetLatest)
    }

    if ($lastGetLatest) {
        [System.TimeSpan]$daysSinceLastGetLatest = [System.TimeSpan]([System.DateTime]::Today - $lastGetLatest.Date)
        return [math]::Round($daysSinceLastGetLatest.TotalDays, 0)
    }
}
