function tfs-get-workspaces {
    $workspacesQueryResult = tf-query-workspaces
    $lines = $workspacesQueryResult | % { $_ }
    for ($i = 3; $i -lt $lines.Count; $i++) {
        $lines[$i].Split(' ')[0]
    }
}

function tf-query-workspaces {
    try {
        execute-native "& `"$tfPath`" workspaces"
    }
    catch {
        Write-Warning "Error querying tf.exe `n $_"
        return $null     
    }
}

function tfs-delete-workspace {
    Param(
        [Parameter(Mandatory=$true)][string]$workspaceName)

    execute-native "& `"$tfPath`" workspace $workspaceName /delete /noprompt"
}

function tfs-create-workspace {
    Param(
        [Parameter(Mandatory=$true)][string]$workspaceName,
        [Parameter(Mandatory=$true)][string]$path
        )
    
    # needed otherwise if the current location is mapped to a workspace the command will throw
    Set-Location $path

    execute-native "& `"$tfPath`" workspace `"$workspaceName`" /new /permission:private /noprompt"
    
    Start-Sleep -m 1000

    try {
        execute-native "& `"$tfPath`" workfold /unmap `"$/`" /workspace:$workspaceName"
    }
    catch {
        try {
            tfs-delete-workspace $workspaceName
        } 
        catch {
            throw "Workspace created but... Error removing default workspace mapping $/. Message: $_"
        }

        throw "WORKSPACE NOT CREATED! Error removing default workspace mapping $/. Message: $_"
    }
}

function tfs-rename-workspace {
    Param(
        [Parameter(Mandatory=$true)][string]$path,
        [Parameter(Mandatory=$true)][string]$newWorkspaceName
        )
    
    try {
        $oldLocation = Get-Location
        Set-Location $path
        execute-native "& `"$tfPath`" workspace /newname:$newWorkspaceName /noprompt"
        Set-Location $oldLocation
    }
    catch {
        Write-Error "Failed to rename workspace. Error: $($_.Exception)"
        return
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
    try {
        execute-native "& `"$tfPath`" workfold /map `"$branch`" `"$branchMapPath`" /workspace:$workspaceName"
    }
    catch {
        Remove-Item $branchMapPath -force
        throw "Error mapping branch to local directory. Message: $_"
    }
}

function tfs-get-latestChanges {
    Param(
        [Parameter(Mandatory=$true)][string]$branchMapPath,
        [switch]$overwrite
        )

    if (-not(Test-Path -Path $branchMapPath)) {
        throw "Get latest changes failed! Branch map path location does not exist: $branchMapPath."
    }

    $oldLocation = Get-Location
    Set-Location -Path $branchMapPath
    if ($overwrite) {
        $output = execute-native "& `"$tfPath`" get /overwrite /noprompt"
    } else {
        $output = execute-native "& `"$tfPath`" get"
    }

    Set-Location $oldLocation

    Write-Host "Success getting latest changes from tfs branch."
}

function tfs-undo-pendingChanges {
    Param(
        [Parameter(Mandatory=$true)][string]$localPath
        )

    execute-native "& `"$tfPath`" undo /recursive /noprompt $localPath"
}

function tfs-get-workspaceName {
    Param(
        [string]$path
        )
    
    $oldLocation = Get-Location
    Set-Location $path
    try {
        $wsInfo = execute-native "& `"$tfPath`" workfold"
    }
    catch {
        Write-Warning "Error querying workspace name: $_"
    }

    Set-Location $oldLocation

    try {
        $wsInfo = $wsInfo.split(':')
        $wsInfo = $wsInfo[2].split('(')
        $wsInfo = $wsInfo[0].trim()
    } catch {
        Write-Warning "No workspace info from TFS! If that is unexpected your credentials could have expired. To renew them login from visual studio..."
        $wsInfo = ''
    }

    return $wsInfo
}

function tfs-get-branchPath {
    Param(
        [string]$path
        )
    
    $oldLocation = Get-Location
    Set-Location $path
    $wsInfo = execute-native "& `"$tfPath`" workfold"
    Set-Location $oldLocation

    try {
        $res = $wsInfo[3].split(':')[0].trim()
    } catch {
        $res = ''
    }

    return $res
}