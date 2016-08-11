Param(
    [Parameter(Mandatory=$true)][string]$tfPath
    )

function tfs-get-workspaces {
        
    [void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client");
    [void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.VersionControl.Client");

    # if no collection specified, open project picker to select it via gui
    $picker = New -Object Microsoft.TeamFoundation.Client.TeamProjectPicker([Microsoft.TeamFoundation.Client.TeamProjectPickerMode]::NoProject, $false)
    $dialogResult = $picker.ShowDialog()
    if ($dialogResult -ne "OK") {
        exit
    }

    $tfs = $picker.SelectedTeamProjectCollection
    $tfs.EnsureAuthenticated()
    $vcs = $tfs.GetService([Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer]);

    $wsname = [System.Management.Automation.Language.NullString]::Value
    $computer = [Environment]::MachineName
    $wss = $vcs.QueryWorkspaces($wsname, $null, $computer)
    foreach($ws in $wss) {
        $ws.Name
    }
}

function tfs-delete-workspace {
    Param(
        [Parameter(Mandatory=$true)][string]$workspaceName)

    $output = & $tfPath workspace $workspaceName /delete /noprompt
    if ($LastExitCode -ne 0)
    {
        throw "$output"
    }
}

function tfs-create-workspace {
    Param(
        [Parameter(Mandatory=$true)][string]$workspaceName,
        [Parameter(Mandatory=$true)][string]$path
        )
    
    # needed otherwise if the current location is mapped to a workspace the command will throw
    Set-Location $path

    $output = & $tfPath workspace $workspaceName /new /permission:private /noprompt 2>&1
    if ($LastExitCode -ne 0)
    {
        throw "$output"
    }

    Start-Sleep -m 1000

    $output = & $tfPath workfold /unmap '$/' /workspace:$workspaceName 2>&1
    if ($LastExitCode -ne 0)
    {
        try {
            tfs-delete-workspace $workspaceName
        } catch {
            throw "Workspace created but... Error removing default workspace mapping $/. Message: $output"
        }

        throw "WORKSPACE NOT CREATED! Error removing default workspace mapping $/. Message: $output"
    }
}

function tfs-create-mappings {
    Param(
        [Parameter(Mandatory=$true)][string]$branch,
        [Parameter(Mandatory=$true)][string]$branchMapPath,
        [Parameter(Mandatory=$true)][string]$workspaceName
        )

    # if (Test-Path -Path $branchMapPath) {
    #     throw "$branchMapPath already exists!"
    # }

    # try {
    #     New-Item $branchMapPath -type directory
    # } catch {
    #     throw "could not create directory $branchMapPath"
    # }

    $output = & $tfPath workfold /map $branch $branchMapPath /workspace:$workspaceName 2>&1
    if ($LastExitCode -ne 0)
    {
        Remove-Item $branchMapPath -force
        throw "Error mapping branch to local directory. Message: $output"
    }
}

function tfs-get-latestChanges {
    Param(
        [Parameter(Mandatory=$true)][string]$branchMapPath
        )

    if (-not(Test-Path -Path $branchMapPath)) {
        throw "Get latest changes failed! Branch map path location does not exist: $branchMapPath."
    }

    $oldLocation = Get-Location
    Set-Location -Path $branchMapPath
    $output = & $tfPath get 2>&1
    Set-Location $oldLocation

    if ($LastExitCode -ne 0)
    {
        throw "Error getting latest changes. Message: $output"
    }   
}