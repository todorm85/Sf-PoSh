
<#
    .SYNOPSIS 
    Renames the current selected sitefinity.
    .PARAMETER markUnused
    If set renames the instanse to '-' and the workspace name to 'unused_{current date}.
    .OUTPUTS
    None
#>
function sf-rename-project {
    [CmdletBinding()]
    Param(
        [switch]$markUnused,
        [switch]$setDescription,
        [switch]$full
    )

    $context = _get-selectedProject

    if ($markUnused) {
        $newName = "-"
        $context.description = ""
        $unusedName = "unused_$(Get-Date | ForEach { $_.Ticks })"
        $newDbName = $unusedName
        $newWebsiteName = $unusedName
        $newProjectName = $unusedName
        $newWsName = $unusedName
    }
    else {
        $oldName = $context.displayName
        $oldName | Set-Clipboard
        while ([string]::IsNullOrEmpty($newName)) {
            $newName = $(Read-Host -Prompt "New name: ").ToString()
            $newDbName = $newName
            $newWebsiteName = $newName
            $newProjectName = $newName
            $newWsName = $newName
        }
        
        if ($setDescription) {
            $context.description = $(Read-Host -Prompt "Enter description:`n").ToString()
        }
    }

    $oldName = _get-solutionName

    $context.displayName = $newName
    _save-selectedProject $context

    $newName = _get-solutionName
    Rename-Item -Path "$($context.solutionPath)\${oldName}" -NewName $newName

    if ($full) {
        
        while ($confirmed -ne 'y' -and $confirmed -ne 'n') {
            $confirmed = Read-Host -Prompt "Full rename will also rename project directory which requires fixing the workspace mapping. Confirm? y/n"
        }

        if ($confirmed -ne 'y') {
            return
        }

        _sf-rename-db $newDbName
        sf-rename-website $newWebsiteName
        _sf-rename-projectDir $newProjectName

        $wsName = tfs-get-workspaceName $context.solutionPath
        tfs-delete-workspace $wsName
        tfs-create-workspace $newWsName $context.solutionPath
        sf-get-latestChanges -overwrite
    }
}


function _sf-rename-db {
    Param($newName)
    
    $context = _get-selectedProject
    $dbName = sf-get-appDbName
    if ([string]::IsNullOrEmpty($dbName)) {
        throw "Sitefinity not initiliazed with a database. No database found in DataConfig.config"
    }

    while (([string]::IsNullOrEmpty($newName)) -or (sql-test-isDbNameDuplicate $newName)) {
        $newName = $(Read-Host -Prompt "Db name duplicate in sql server! Enter new db name: ").ToString()
    }

    try {
        sql-rename-database $dbName $newName
    }
    catch {
        Write-Error "Failed renaming database in sql server.Message: $($_.Exception)"        
        return
    }

    try {
        sf-set-appDbName $newName
    }
    catch {
        Write-Error "Failed renaming database in dataConfig"
        sql-rename-database $newName $dbName
        return
    }

    _save-selectedProject $context
}

function _sf-rename-projectDir {
    Param(
        [string]$newName
    )

    $context = _get-selectedProject

    sf-reset-pool
    $hasSolution = $context.solutionPath -ne "" -and $context.solutionPath -ne $null
    try {
        Set-Location -Path $Env:HOMEDRIVE
        if ($hasSolution) {
            $confirmed = Read-Host -Prompt "Renaming the project directory will loose tfs workspace mapping if there is one. You need to manually fix it later. Are you sure? y/n"
            if ($confirmed -ne 'y') {
                return
            }

            $parentPath = (Get-Item $context.solutionPath).Parent
            Rename-Item -Path $context.solutionPath -NewName $newName -Force
            $context.solutionPath = "$($parentPath.FullName)\${newName}"
            $context.webAppPath = "$($context.solutionPath)\SitefinityWebApp"
        }
        else {
            $parentPath = (Get-Item $context.webAppPath).Parent
            Rename-Item -Path $context.webAppPath -NewName $newName -Force
            $context.webAppPath = "$($parentPath.FullName)\${newName}"
        }
    }
    catch {
        Write-Error "Error renaming solution. Message: $($_.Exception)"
        return
    }

    Get-Item ("iis:\Sites\$($context.websiteName)") | Set-ItemProperty -Name "physicalPath" -Value $context.webAppPath

    _save-selectedProject $context
}
