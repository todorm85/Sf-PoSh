if ($false) {
    . .\..\sf-all-dependencies.ps1 # needed for intellisense
}

<#
    .SYNOPSIS 
    Provisions a new sitefinity instance project. 
    .DESCRIPTION
    Gets latest from the branch, builds and starts a sitefinity instance with default admin user username:admin pass:admin@2. The local path where the project files are created is specified in the constants script file (EnvConstants.ps1).
    .PARAMETER name
    The name of the new sitefinity instance.
    .PARAMETER branch
    The tfs branch from which the Sitefinity source code is downloaded.
    .PARAMETER buildSolution
    Builds the solution after downloading from tfs.
    .PARAMETER startWebApp
    Starts webapp after building the solution.
    .OUTPUTS
    None
#>
function sf-provision-sitefinity {
    [CmdletBinding()]
    Param(
        [string]$name,
        [string]$branch = "$/CMS/Sitefinity 4.0/Code Base",
        [switch]$buildSolution,
        [switch]$startWebApp
        )

    $defaultContext = _sfData-get-defaultContext $name
    try {
        $newContext = @{ name = $defaultContext.name }
        $newContext.displayName = $defaultContext.displayName
        if (Test-Path $defaultContext.solutionPath) {
            throw "Path already exists:" + $defaultContext.solutionPath
        }

        Write-Host "Creating solution path..."
        New-Item $defaultContext.solutionPath -type directory > $null
        $newContext.solutionPath = $defaultContext.solutionPath;

        # create and map workspace
        Write-Host "Creating workspace..."
        $workspaceName = $defaultContext.displayName
        tfs-create-workspace $workspaceName $defaultContext.solutionPath

        Write-Host "Creating workspace mappings..."
        tfs-create-mappings -branch $branch -branchMapPath $defaultContext.solutionPath -workspaceName $workspaceName
        $newContext.branch = $branch

        Write-Host "Getting latest workspace changes..."
        tfs-get-latestChanges -branchMapPath $defaultContext.solutionPath

        # persist current context to script data
        $newContext.dbName = $defaultContext.dbName
        $newContext.webAppPath = $defaultContext.solutionPath + '\SitefinityWebApp'
        $oldContext = ''
        $oldContext = _sfData-get-currentContext
        _sfData-set-currentContext $newContext
        _sfData-save-context $newContext
    } catch {
        Write-Error "############ CLEANING UP ############"
        Set-Location $PSScriptRoot

        
        if ($newContext.solutionPath -ne '' -and $newContext.solutionPath -ne $null) {
            if (tfs-get-workspaceName -ne '') {
                tfs-delete-workspace $workspaceName
            }

            Remove-Item -Path $newContext.solutionPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError -Recurse
            if ($ProcessError) {
                Write-Error $ProcessError
            }
        }
        

        if ($oldContext -ne '') {
            _sfData-set-currentContext $oldContext
        }

        throw "Nothing created. Try again. Error: $_"
    }

    try {
        if ($buildSolution) {
            Write-Host "Building solution..."
            sf-build-solution
        }
    } catch {
        $startWebApp = $false
        Write-Warning "SOLUTION WAS NOT BUILT. Message: $_.Exception.Message"
    }

    try {
        Write-Host "Creating website..."
        _sf-create-website -newWebsiteName $defaultContext.websiteName -newPort $defaultContext.port -newAppPool $defaultContext.appPool
    } catch {
        $startWebApp = $false
        Write-Warning "WEBSITE WAS NOT CREATED. Message: $_.Exception.Message"
    }

    if ($startWebApp) {
        try {
            Write-Host "Initializing Sitefinity"
            _sf-create-startupConfig
            _sf-start-sitefinity
        } catch {
            Write-Warning "APP WAS NOT INITIALIZED. $_.Exception.Message"
            _sf-delete-startupConfig
        }
    }

    # Display message
    os-popup-notification "Operation completed!"
}

New-Alias -name ns -value sf-provision-sitefinity

<#
    .SYNOPSIS 
    Imports a new sitefinity instance project from given local path. 
    .DESCRIPTION
    A sitefinity web app project or Sitefinity solution can be imported. 
    .PARAMETER displyName
    The name of the imported sitefinity instance.
    .PARAMETER path
    The directory which contains either Telerik.Sitefinity.sln or SitefinityWebApp.csproj files. The app automatically detects whether the full Sitefinity source code or just the webapp that uses Sitefinity CMS is available.
    .OUTPUTS
    None
#>
function sf-import-sitefinity {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][string]$displayName,
        [Parameter(Mandatory=$true)][string]$path
        )

    if (!(Test-Path $path)) {
        throw "Invalid path"
    }

    $isSolution = Test-Path "$path\Telerik.Sitefinity.sln"
    $isWebApp = Test-Path "$path\web.config"
    if (-not $isWebApp -and -not $isSolution) {
        throw "No web app or solution found."
    }

    if ($isWebApp -and $isSolution) {
        throw "Cannot determine whether webapp or solution."
    }

    $defaultContext = _sfData-get-defaultContext $displayName
    $newContext = @{ name = $defaultContext.name }
    $newContext.displayName = $defaultContext.displayName
    if ($isSolution) {
        $newContext.solutionPath = $path
        $newContext.webAppPath = $path + '\SitefinityWebApp'
    } else {
        $newContext.solutionPath = ''
        $newContext.webAppPath = $path
    }

    while ($appInitialized -ne 'y' -and $appInitialized -ne 'n') {
        $appInitialized = Read-Host -Prompt 'Is your app initialized with a database? [y/n]'
    }

    if ($appInitialized -eq 'y') {
        $isDuplicate = $false
        while (!$isDuplicate) {
            $dbName = Read-Host -Prompt 'Enter database name: '
            $isDuplicate = sql-test-isDbNameDuplicate $dbName
        }

        $newContext.dbName = $dbName
    } else {
        $newContext.dbName = $defaultContext.dbName
    }

    while ($hasWebSite -ne 'y' -and $hasWebSite -ne 'n') {
        $hasWebSite = Read-Host -Prompt 'Does your app has a website created for it? [y/n]'
    }

    if ($hasWebSite -eq 'y') {
        $isDuplicate = $false
        while (!$isDuplicate) {
            $websiteName = Read-Host -Prompt 'Enter website name: '
            $isDuplicate = iis-test-isSiteNameDuplicate $websiteName
            $newContext.websiteName = $websiteName
        }
    } else {
        try {
            Write-Host "Creating website..."
            
            $isDuplicateSite = $true
            while ($isDuplicateSite) {
                $isDuplicateSite = iis-test-isSiteNameDuplicate $defaultContext.websiteName
                if ($isDuplicateSite) {
                    $defaultContext.websiteName = Read-Host -Prompt "Enter site name"
                }
            }

            _sfData-set-currentContext $newContext
            _sf-create-website -newWebsiteName $defaultContext.websiteName -newPort $defaultContext.port -newAppPool $defaultContext.appPool
            $newContext.websiteName = $defaultContext.websiteName
        } catch {
            $startWebApp = $false
            Write-Warning "WEBSITE WAS NOT CREATED. Message: $_.Exception.Message"
        }
    }

    _sfData-save-context $newContext

    # Display message
    os-popup-notification "Operation completed!"
}

<#
    .SYNOPSIS 
    Deletes a sitefinity instance managed by the script.
    .DESCRIPTION
    Everything is deleted - local project files, database, TFS workspace if no switches are passed. 
    .PARAMETER keepWorkspace
    Keeps the workspace if one exists.
    .PARAMETER keepProjectFiles
    Keeps the project files.
    .PARAMETER keepProjectFiles
    Forces the deletion by resetting IIS to free any locked files by the app.
    .OUTPUTS
    None
#>
function sf-delete-sitefinity {
    [CmdletBinding()]
    Param(
        [switch]$keepWorkspace,
        [switch]$keepProjectFiles,
        [switch]$force
        )
    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    $workspaceName = tfs-get-workspaceName $context.webAppPath
    $dbName = $context.dbName
    $websiteName = $context.websiteName

    # while ($true) {
    #     $isConfirmed = Read-Host -Prompt "WARNING! Current operation will reset IIS. You also need to have closed the current sitefinity solution in Visual Studio and any opened browsers for complete deletion. Continue [y/n]?"
    #     if ($isConfirmed -eq 'y') {
    #         break;
    #     }

    #     if ($isConfirmed -eq 'n') {
    #         return
    #     }
    # }

    Set-Location -Path $PSScriptRoot

    # Del workspace
    if ($workspaceName -ne '' -and !($keepWorkspace)) {
        Write-Host "Deleting workspace..."
        try {
            tfs-delete-workspace $workspaceName
        } catch {
            Write-Host "Could not delete workspace $_.Exception.Message"
        }
    }

    # Del db
    Write-Host "Deleting sitefinity database..."
    if ($dbName -ne '') {
        try {
            sql-delete-database -dbName $dbName
        } catch {
            Write-Host "Could not delete database: ${dbName}. $_.Exception.Message"
        }
    }

    # Del Website
    Write-Host "Deleting website..."
    if ($websiteName -ne '') {
        try {
            _sf-delete-website
        } catch {
            Write-Host "Could not delete website ${websiteName}. $_.Exception.Message"
        }
    }

    # Del dir
    if (!($keepProjectFiles)) {
        try {
            if ($force) {
                Write-Host "Resetting IIS..."
                iisreset.exe > $null
            }

            Write-Host "Deleting solution directory..."
            
            if ($solutionPath -ne "") {
                Remove-Item $solutionPath -recurse -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            } else {
                Remove-Item $context.webAppPath -recurse -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            }

            if ($ProcessError) {
                throw $ProcessError
            }
        } catch {
            Write-Host "Errors deleting sitefinity directory. $_.Exception.Message"
        }
    }

    Write-Host "Deleting data entry..."
    _sfData-delete-context $context
    _sfData-set-currentContext $null

    # Display message
    os-popup-notification -msg "Operation completed!"

    sf-select-sitefinity
}

<#
    .SYNOPSIS 
    Displays a list of available sitefinities to select from.
    .DESCRIPTION
    Sitefinities that are displayed are displayed by their names. These are sitefinities that were either provisioned or imported by this script. 
    .OUTPUTS
    None
#>
function sf-select-sitefinity {
    [CmdletBinding()]Param()

    $sitefinities = @(_sfData-get-allContexts)

    sf-show-allSitefinities

    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose sitefinity'
        $selectedSitefinity = $sitefinities[$choice]
        if ($selectedSitefinity -ne $null) {
            break;
        }
    }

    _sfData-set-currentContext $selectedSitefinity
    Set-Location $selectedSitefinity.webAppPath
}

New-Alias -name ss -value sf-select-sitefinity

<#
    .SYNOPSIS 
    Renames the current selected sitefinity.
    .PARAMETER markUnused
    If set renames the instanse to '-' and the workspace name to 'unused_{current date}.
    .OUTPUTS
    None
#>
function sf-set-description {
    $context = _sf-get-context

    $context.description = $(Read-Host -Prompt "Enter description: ").ToString()

    _sfData-save-context $context
}

New-Alias -name sd -value sf-set-description

<#
    .SYNOPSIS 
    Renames the current selected sitefinity.
    .PARAMETER markUnused
    If set renames the instanse to '-' and the workspace name to 'unused_{current date}.
    .OUTPUTS
    None
#>
function sf-rename-sitefinity {
    [CmdletBinding()]
    Param(
        [switch]$markUnused,
        [switch]$setDescription,
        [switch]$full
    )

    $context = _sf-get-context

    if ($markUnused) {
        $newName = "-"
        $context.description = ""
        $unusedName = "unused_$(Get-Date | ForEach { $_.Ticks })"
        $newDbName = $unusedName
        $newWebsiteName = $unusedName
        $newProjectName = $unusedName
        $newWsName = $unusedName
    } else {
        while ([string]::IsNullOrEmpty($newName)) {
            $newName = $(Read-Host -Prompt "Enter new name: ").ToString()
            $newDbName = $newName
            $newWebsiteName = $newName
            $newProjectName = $newName
            $newWsName = $newName
        }
        
        if ($setDescription) {
            $context.description = $(Read-Host -Prompt "Enter description:`n").ToString()
        }
    }

    $context.displayName = $newName
    _sfData-save-context $context

    if ($full) {
        
        while($confirmed -ne 'y' -and $confirmed -ne 'n') {
            $confirmed = Read-Host -Prompt "Full rename will also rename project directory which requires fixing the workspace mapping. Confirm? y/n"
        }

        if ($confirmed -ne 'y') {
            return
        }

        sf-rename-db $newDbName
        sf-rename-website $newWebsiteName
        sf-rename-projectDir $newProjectName

        $wsName = tfs-get-workspaceName $context.solutionPath
        tfs-delete-workspace $wsName
        tfs-create-workspace $newWsName $context.solutionPath
        sf-get-latest -overwrite
    }
}

New-Alias -name rs -value sf-rename-sitefinity

function sf-rename-db {
    Param($newName)
    
    $context = _sf-get-context
    if ([string]::IsNullOrEmpty($context.dbName)) {
        throw "No current database set"
    }

    while (sql-test-isDbNameDuplicate $newName) {
        $newName = $(Read-Host -Prompt "Db name duplicate in sql server! Enter new db name: ").ToString()
    }

    try {
        sql-rename-database $context.dbName $newName
    }
    catch {
        Write-Error "Failed renaming database in sql server.Message: $($_.Exception)"        
        return
    }

    try {
        $data = New-Object XML
        $dataConfigPath = "$($context.webAppPath)\App_Data\Sitefinity\Configuration\DataConfig.config"
        $data.Load($dataConfigPath) > $null
        $conStrElement = $data.dataConfig.connectionStrings.add
        $newString = $conStrElement.connectionString -replace $context.dbName, $newName
        $conStrElement.SetAttribute("connectionString", $newString)
        $data.Save($dataConfigPath) > $null
    }
    catch {
        Write-Error "Failed renaming database in dataConfig"
        sql-rename-database $newName $context.dbName
        return
    }

    $context.dbName = $newName
    _sfData-save-context $context
}

function sf-rename-projectDir {
    Param(
        [string]$newName
    )

    $context = _sf-get-context

    sf-reset-pool
    $hasSolution = $context.solutionPath -ne "" -and $context.solutionPath -ne $null
    try {
        Set-Location -Path $Env:HOMEDRIVE
        if ($hasSolution) {
            $confirmed = Read-Host -Prompt "Renaming the project directory will loose tfs workspace mapping if there is one. You need to manually fix it later. Are you sure? y/n"
            if ($confirmed -ne 'y') {
                return
            }

            # $oldWorkspaceName = tfs-get-workspaceName $context.webAppPath

            $parentPath = (Get-Item $context.solutionPath).Parent
            Rename-Item -Path $context.solutionPath -NewName $newName -Force
            $context.solutionPath = "$($parentPath.FullName)\${newName}"
            $context.webAppPath = "$($context.solutionPath)\SitefinityWebApp"

            # tfs-delete-workspace $oldWorkspaceName
            # tfs-create-workspace $oldWorkspaceName $context.solutionPath
            # tfs-create-mappings -branch $context.branch -branchMapPath $context.solutionPath -workspaceName $oldWorkspaceName
        } else {
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

    _sfData-save-context $context
    # sf-get-latest -overwrite
}

<#
    .SYNOPSIS 
    Shows info for selected sitefinity.
#>
function sf-show-currentSitefinity {
    [CmdletBinding()]
    Param([switch]$detail)
    $context = _sf-get-context

    if (-not $detail) {
        Write-Host "`n$($colntext.name) | $($context.displayName) | $($context.branch) | $($context.port)`n"
        return    
    }

    $ports = @(iis-get-websitePort $context.websiteName)
    $appPool = @(iis-get-siteAppPool $context.websiteName)
    $workspaceName = tfs-get-workspaceName $context.webAppPath
    # $mapping = tfs-get-mappings $context.webAppPath

    $otherDetails = @(
        [pscustomobject]@{id = -1; Parameter = "Title"; Value = $context.displayName;},
        [pscustomobject]@{id = 0; Parameter = "Id"; Value = $context.name;},
        [pscustomobject]@{id = 1; Parameter = "Solution path"; Value = $context.solutionPath;},
        [pscustomobject]@{id = 2; Parameter = "Web app path"; Value = $context.webAppPath;},
        [pscustomobject]@{id = 3; Parameter = "Database Name"; Value = $context.dbName;},
        [pscustomobject]@{id = 1; Parameter = "Website Name in IIS"; Value = $context.websiteName;},
        [pscustomobject]@{id = 2; Parameter = "Ports"; Value = $ports;},
        [pscustomobject]@{id = 3; Parameter = "Application Pool Name"; Value = $appPool;},
        [pscustomobject]@{id = 1; Parameter = "Workspace name"; Value = $workspaceName;},
        [pscustomobject]@{id = 2; Parameter = "Mapping"; Value = $context.branch;}
    )

    $otherDetails | Sort-Object -Property id | Format-Table -Property Parameter, Value -auto -HideTableHeaders
    Write-Host "Description:`n$($context.description)`n"
}

New-Alias -name s -value sf-show-currentSitefinity

<#
    .SYNOPSIS 
    Shows info for all sitefinities managed by the script.
#>
function sf-show-allSitefinities {
    $sitefinities = @(_sfData-get-allContexts)
    if ($sitefinities[0] -eq $null) {
        Write-Host "No sitefinities! Create one first. sf-create-sitefinity or manually add in sf-data.xml"
        return
    }
    
    [System.Collections.ArrayList]$output = @()
    foreach ($sitefinity in $sitefinities) {
        $ports = @(iis-get-websitePort $sitefinity.websiteName)
        # $mapping = tfs-get-mappings $sitefinity.webAppPath
        # if ($mapping) {
        #     $mapping = $mapping.split("4.0")[3]
        # }

        $index = [array]::IndexOf($sitefinities, $sitefinity)

        $output.add([pscustomobject]@{order = $index; Title = "$index : $($sitefinity.displayName)"; Branch = $sitefinity.branch.split("4.0")[3]; Ports = "$ports"; ID = "$($sitefinity.name)";}) > $null
    }

    $output | Sort-Object -Property order | Format-Table -Property Title, Branch, Ports, Id -auto
}

New-Alias -name sa -value sf-show-allSitefinities
