# used for tfs workspace manipulations, installed with Visual Studio
# $tfPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\tf.exe" #VS2015
$tfPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\TF.exe" #VS2017

if (-not (Test-Path $tfPath)) {
    throw "You must install Visual Studio 2017 Professional to use TFS utilities."
}

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

function tfs-checkout-file {
    Param(
        [Parameter(Mandatory=$true)][string]$filePath
        )

    $oldLocation = Get-Location
    $newLocation = Split-Path $filePath -Parent
    $fileName = Split-Path $filePath -Leaf
    Set-Location $newLocation
    try {
        execute-native "& `"$tfPath`" checkout $fileName"
    }
    catch {
        throw "Error checking out file $filePath. Message: $_"
    }
    finally {
        Set-Location $oldLocation
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
        $output = execute-native "& `"$tfPath`" get /overwrite /noprompt" -successCodes @(1)
    } else {
        $output = execute-native "& `"$tfPath`" get" -successCodes @(1)
    }

    if ($global:LASTEXITCODE -eq 1) {
        $output -match ".*?(?<conflicts>\d+) conflicts, \d+ warnings, (?<errors>\d+) errors.*"
        $conflictsCount = [int]::Parse($Matches.conflicts)
        $errorsCount = [int]::Parse($Matches.errors)
        if ($conflictsCount -gt 0) {
            throw "There were $conflictsCount conflicts when getting latest."
        }
        elseif ($errorsCount -gt 0) {
            throw "There were $errorsCount errors when getting latest."
        }
    }

    Set-Location $oldLocation
    
    return $output
}

function tfs-undo-pendingChanges {
    Param(
        [Parameter(Mandatory=$true)][string]$localPath
        )

    execute-native "& `"$tfPath`" undo /recursive /noprompt $localPath" -successCodes @(1)
}

function tfs-show-pendingChanges {
    Param(
        [Parameter(Mandatory=$true)][string]$workspaceName,
        [ValidateSet("Detailed","Brief")][string]$format)

    execute-native "& `"$tfPath`" stat /workspace:$workspaceName /format:$format"
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
    try {
        Set-Location $path
        $wsInfo = execute-native "& `"$tfPath`" workfold"
    }
    catch {
        Set-Location $oldLocation
        if ($global:LASTEXITCODE -eq 100) {
            $wsInfo = ''
        } else {
            throw $_
        }
    }

    try {
        $res = $wsInfo[3].split(':')[0].trim()
    } catch {
        $res = ''
    }

    return $res
}

function tfs-get-lastWorkspaceChangeset {
    param (
        $path
    )

    $oldLocation = Get-Location
    Set-Location $path
    $wsInfo = execute-native "& `"$tfPath`" history . /recursive /stopafter:1 -version:W /noprompt"
    Set-Location $oldLocation
    return $wsInfo
}