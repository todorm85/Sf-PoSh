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
    
    $sitefinities = @(_sfData-get-allProjects -skipInit)
    if (!$sitefinities[0]) {
        Write-Warning "No sitefinities! Create one first. sf-create-sitefinity or manually add in sf-data.xml"
        return
    }

    if (!$showUnused) {
        $unusedProjectsName = _get-unusedProjectName
        $sitefinities = $sitefinities | Where-Object { ([SfProject]$_).displayName -ne $unusedProjectsName }
    }

    $selectedSitefinity = prompt-projectSelect -sitefinities $sitefinities

    set-currentProject $selectedSitefinity
    
    sf-show-currentProject
}

function prompt-projectSelect {
    param (
        [SfProject[]]$sitefinities
    )

    if (-not $sitefinities) {
        Write-Warning "No sitefinities found. Make sure you are showing unused as well or create some."
        return
    }
    
    $sitefinities = $sitefinities | Sort-Object -Property @{Expression = "displayName" }, @{Expression = "branch" }
    sf-show-projects $sitefinities
    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose sitefinity'
        $selectedSitefinity = $sitefinities[$choice]
        if ($null -ne $selectedSitefinity) {
            break;
        }
    }

    $selectedSitefinity
}

<#
    .SYNOPSIS 
    Shows info for selected sitefinity.
#>
function sf-show-currentProject {
    Param(
        [switch]$detail,
        [SfProject]$context
    )

    if (!$context) {
        $context = _get-selectedProject
    }
    
    if ($null -eq ($context)) {
        Write-Warning "No project selected"
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

    try {
        $workspaceName = tfs-get-workspaceName $context.webAppPath
        $branch = tfs-get-branchPath $context.solutionPath
    }
    catch {
        Write-Warning "Error getting some details from TFS: $_"    
    }

    try {
        $appPool = @(iis-get-siteAppPool $context.websiteName)
    }
    catch {
        Write-Warning "Error getting some details from IIS: $_"    
    }

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

    $details = $otherDetails | Sort-Object -Property id | Format-Table -Property Parameter, Value -AutoSize -Wrap -HideTableHeaders | Out-String
    Write-Host $details
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
        
        $output.add([pscustomobject]@{order = $index; Title = "$index : $($sitefinity.displayName)"; Branch = $sitefinity.branch.Split([string[]]("$/CMS/Sitefinity 4.0"), [System.StringSplitOptions]::RemoveEmptyEntries)[0]; Ports = "$ports"; ID = "$($sitefinity.id)"; LastGet = _get-daysSinceLastGetLatest $sitefinity }) > $null
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

function prompt-predefinedBranchSelect {
    [Config]$conf = _get-config
    $branches = @($conf.predefinedBranches)

    if ($branches.Count -eq 0) {
        $selectedBranch = Read-Host -Prompt 'No predefined branches, enter branch path'
        return $selectedBranch
    }

    $i = 0
    foreach ($branch in $branches) {
        $i++
        Write-Host "[$i] : $branch"
    }

    $selectedBranch = $null
    while (!$selectedBranch) {
        $userInput = Read-Host -Prompt "Select branch"
        $selectedBranch = $branches[$userInput - 1]
    }

    return $selectedBranch
}