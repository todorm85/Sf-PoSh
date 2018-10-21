<#
    .SYNOPSIS 
    Provisions a new sitefinity instance project. 
    .DESCRIPTION
    Gets latest from the branch, builds and starts a sitefinity instance with default admin user username:admin pass:admin@2. The local path where the project files are created is specified in the constants script file (EnvConstants.ps1).
    .PARAMETER name
    The name of the new sitefinity instance.
    .PARAMETER branch
    The tfs branch from which the Sitefinity source code is downloaded. It has predefined values that can be iterated by pressing tab repeatedly.
    .PARAMETER buildSolution
    Builds the solution after downloading from tfs.
    .PARAMETER startWebApp
    Starts webapp after building the solution.
    .OUTPUTS
    None
#>
function sf-new-project {
    [CmdletBinding()]
    Param(
        [string]$displayName,
        [switch]$buildSolution,
        [switch]$startWebApp,
        [switch]$precompile,
        [string]$customBranch
    )

    DynamicParam {
        # Set the dynamic parameters' name
        $ParameterName = 'predefinedBranch'
        
        # Create the dictionary 
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        # Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        
        # Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $false
        $ParameterAttribute.Position = 1

        # Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)

        # Generate and set the ValidateSet 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($predefinedBranches)

        # Add the ValidateSet to the attributes collection
        $AttributeCollection.Add($ValidateSetAttribute)

        # Create and return the dynamic parameter
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    begin {
        # Bind the parameter to a friendly variable
        $predefinedBranch = $PsBoundParameters[$ParameterName]
    }

    process {
        if ($null -ne $predefinedBranch) {
            $branch = $predefinedBranch
        }
        else {
            $branch = $customBranch
        }

        [SfProject]$newContext = new-SfProject -displayName $displayName
        if (Test-Path $newContext.solutionPath) {
            throw "Path already exists:" + $newContext.solutionPath
        }

        try {
            Write-Host "Creating solution path..."
            New-Item $newContext.solutionPath -type directory > $null

            $newContext.branch = $branch
            _create-workspace $newContext -branch $branch

            $webAppPath = $newContext.solutionPath + '\SitefinityWebApp'
            $newContext.webAppPath = $webAppPath

            Write-Host "Backing up original App_Data folder..."
            $originalAppDataSaveLocation = "$webAppPath/sf-dev-tool/original-app-data"
            New-Item -Path $originalAppDataSaveLocation -ItemType Directory > $null
            Copy-Item -Path "$webAppPath\App_Data\*" -Destination $originalAppDataSaveLocation -Recurse > $null

            # persist current context to script data
            $oldContext = _get-selectedProject
            set-currentProject $newContext
            _save-selectedProject $newContext
        }
        catch {
            Write-Warning "############ CLEANING UP ############"
            Set-Location $PSScriptRoot
        
            try {
                Write-Host "Deleting workspace..."
                tfs-delete-workspace $newContext.id
            }
            catch {
                Write-Warning "No workspace created to delete."
            }

            try {
                Write-Host "Deleting solution..."
                Remove-Item -Path $newContext.solutionPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError -Recurse
            }
            catch {
                Write-Warning "Could not delete solution directory"
            }

            if ($oldContext) {
                set-currentProject $oldContext
            }
            
            # $displayInnerError = Read-Host "Display inner error? y/n"
            # if ($displayInnerError -eq 'y') {
            #     Write-Host "`n"
            #     Write-Host $_
            #     Write-Host "`n"
            # }

            Write-Host $_
            return
        }

        _create-userFriendlySlnName $newContext

        if ($buildSolution) {
            Write-Host "Building solution..."
            $tries = 0
            $retryCount = 3
            $isBuilt = $false
            while ($tries -le $retryCount -and (-not $isBuilt)) {
                try {
                    $output = sf-build-solution
                    $isBuilt = $true
                }
                catch {
                    Write-Host "Build failed."
                    if ($tries -le $retryCount) {
                        Write-Host "Retrying..." 
                        $tries++
                    }
                    else {
                        Write-Error "Solution could not build after $retryCount retries. Last error: $output"
                    }
                }
            }
        }
            
        try {
            Write-Host "Creating website..."
            create-website -context $newContext
        }
        catch {
            $startWebApp = $false
            Write-Warning "Error creating website. Message: $_"
        }

        if ($startWebApp) {
            try {
                Write-Host "Initializing Sitefinity"
                create-startupConfig
                start-app
                if ($precompile) {
                    sf-add-precompiledTemplates
                }
            }
            catch {
                Write-Warning "APP WAS NOT INITIALIZED. $_"
                delete-startupConfig
            }
        }        

        # Display message
        os-popup-notification "Operation completed!"
    }
}

function sf-clone-project {
    [SfProject]$context = _get-selectedProject
    $sourcePath = $context.solutionPath;
    if ([string]::IsNullOrEmpty($sourcePath)) {
        $sourcePath = $context.webAppPath
    }

    if ([string]::IsNullOrEmpty($sourcePath) -or -not (Test-Path $sourcePath)) {
        throw "Invalid app path";
    }

    $targetName = _generateId
    $targetPath = $script:projectsDirectory + "\${targetName}"
    if (Test-Path $targetPath) {
        throw "Path exists: ${targetPath}"
    }

    try {
        Write-Information "Copying $sourcePath to $targetPath."
        New-Item $targetPath -ItemType Directory > $null
        Copy-Item "${sourcePath}\*" $targetPath -Recurse
    }
    catch {
        throw "Error copying source files.`n $_"        
    }

    try {
        $branch = tfs-get-branchPath -path $sourcePath

        sf-import-project -displayName "$($context.displayName)-clone" -path $targetPath -branch $branch -cloneDb $true
    }
    catch {
        throw "Error importing project.`n $_"        
    }

    try {
        sf-delete-allAppStates
    }
    catch {
        throw "Error deleting app states.`n $_"        
    }
}

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
function sf-import-project {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$displayName,
        [Parameter(Mandatory = $true)][string]$path,
        [Parameter(Mandatory = $true)][bool]$cloneDb,
        [string]$websiteName,
        [string]$branch
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

    [SfProject]$newContext = new-SfProject
    $newContext.displayName = $displayName
    if ($isSolution) {
        $newContext.solutionPath = $path
        $newContext.webAppPath = $path + '\SitefinityWebApp'
        if ($branch) {
            $newContext.branch = $branch
            _create-workspace -context $newContext -branch $branch
        }

        _create-userFriendlySlnName $newContext
    }
    else {
        $newContext.solutionPath = ''
        $newContext.webAppPath = $path
    }

    $oldContext = _get-selectedProject
    set-currentProject $newContext
    try {
        _save-selectedProject $newContext
    }
    catch {
        set-currentProject $oldContext
        throw "Could not import sitefinity. Could not write project to db. $($_)"
    }

    # while ($prompt -ne 'c' -and $prompt -ne 'u') {
    #     $prompt = Read-Host -Prompt '[c]reate new website or [u]se existing?'
    # }

    # $useExistingWebSite = $prompt -eq 'u'

    if ($websiteName) {
        $newContext.websiteName = $websiteName
    }

    try {
        Write-Host "Creating website..."
        create-website -context $newContext > $null
    }
    catch {
        Write-Warning "Error during website creation. Message: $_"
        $newContext.websiteName = ""
    }

    $currentDbName = sf-get-appDbName
    if ($currentDbName) {
        # while ($useCopy -ne 'y' -and $useCopy -ne 'n') {
        #     $useCopy = Read-Host -Prompt 'Clone existing database? [y/n]'
        # }

        if ($cloneDb) {
            try {
                sf-set-appDbName $newContext.id
            }
            catch {
                Write-Warning "Error setting new database name in config ($($newContext.id)).`n $_"                    
            }
                    
            try {
                sql-copy-db $currentDbName $newContext.id                    
            }
            catch {
                Write-Warning "Error copying old database. Source: $currentDbName Target $($newContext.id)`n $_"
            }
        }
    }
    
    os-popup-notification "Operation completed!"
}

function sf-delete-projects {
    $sitefinities = @(get-allProjectsForCurrentContainer)
    if ($null -eq $sitefinities[0]) {
        Write-Host "No projects found. Create one."
        return
    }

    sf-show-allProjects

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

    foreach ($selectedSitefinity in $sfsToDelete) {
        try {
            sf-delete-project -context $selectedSitefinity -noPrompt
        }
        catch {
            Write-Error "Error deleting project with id = $($selectedSitefinity.id)"                
        }
    }
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
function sf-delete-project {
    [CmdletBinding()]
    Param(
        [switch]$keepDb,
        [switch]$keepWorkspace,
        [switch]$keepProjectFiles,
        [switch]$force,
        [switch]$noPrompt,
        [SfProject]$context = $null
    )
    
    if ($null -eq $context) {
        $context = _get-selectedProject
    }

    $solutionPath = $context.solutionPath
    $workspaceName = tfs-get-workspaceName $context.webAppPath
    $dbName = sf-get-appDbName $context
    $websiteName = $context.websiteName
    
    if ($websiteName) {
        try {
            sf-stop-pool -context $context
        }
        catch {
            Write-Warning "Could not stop app pool: $_"            
        }
    }

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
        }
        catch {
            Write-Warning "Could not delete workspace $_"
        }
    }

    # Del db
    if (-not [string]::IsNullOrEmpty($dbName) -and (-not $keepDb)) {
        Write-Host "Deleting sitefinity database..."
        try {
            sql-delete-database -dbName $dbName
        }
        catch {
            Write-Warning "Could not delete database: ${dbName}. $_"
        }
    }

    # Del Website
    Write-Host "Deleting website..."
    if ($websiteName) {
        try {
            delete-website $context
        }
        catch {
            Write-Warning "Errors deleting website ${websiteName}. $_"
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
            }
            else {
                Remove-Item $context.webAppPath -recurse -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            }

            if ($ProcessError) {
                throw $ProcessError
            }
        }
        catch {
            Write-Warning "Errors deleting sitefinity directory. $_"
        }
    }

    Write-Host "Deleting data entry..."
    _sfData-delete-project $context
    set-currentProject $null

    if (-not ($noPrompt)) {
        sf-select-project
    }
}

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
        [switch]$setDescription
    )

    [SfProject]$context = _get-selectedProject
    $oldName = $context.displayName

    if ($markUnused) {
        $newName = "unused"
        $context.description = ""
    }
    else {
        $oldName | Set-Clipboard
        while ([string]::IsNullOrEmpty($newName) -or (-not (validate-nameSyntax $newName))) {
            if ($newName) {
                Write-Warning "Invalid name syntax."
            }

            $newName = $(Read-Host -Prompt "Enter new project name").ToString()
        }

        if ($setDescription) {
            $context.description = $(Read-Host -Prompt "Enter description:`n").ToString()
        }
    }

    $oldSolutionName = _get-solutionFriendlyName
    if (-not $oldSolutionName) {
        _create-userFriendlySlnName -context $context
        $oldSolutionName = _get-solutionFriendlyName
    }

    $oldDomain = get-domain
    $context.displayName = $newName
    _save-selectedProject $context
    set-currentProject $context

    $newSolutionName = _get-solutionFriendlyName
    Rename-Item -Path "$($context.solutionPath)\${oldSolutionName}" -NewName $newSolutionName

    try {
        Remove-Domain $oldDomain
    }
    catch {
        # nothing to remove        
    }
    
    $domain = get-domain
    $websiteName = $context.websiteName
    $ports = @(iis-get-websitePort $websiteName)
    Add-Domain $domain $ports[0]
}

function _create-userFriendlySlnName ($context) {
    $solutionFilePath = "$($context.solutionPath)\Telerik.Sitefinity.sln"
    $targetFilePath = "$($context.solutionPath)\$(_get-solutionFriendlyName $context)"
    Copy-Item -Path $solutionFilePath -Destination $targetFilePath
}

function _save-selectedProject {
    Param($context)

    _validate-project $context

    _sfData-save-project $context
}

function _validate-project {
    Param($context)

    if ($null -ne $context) {
        if ($context.id -eq '') {
            throw "Invalid sitefinity context. No sitefinity id."
        }

        if ($context.solutionPath -ne '') {
            if (-not (Test-Path $context.solutionPath)) {
                throw "Invalid sitefinity context. Solution path does not exist."
            }
        }
        
        if (-not $context.webAppPath -and -not(Test-Path $context.webAppPath)) {
            throw "Invalid sitefinity context. No web app path or it does not exist."
        }
    }
}

function _get-isIdDuplicate ($name) {
    $sitefinities = [SfProject[]]@(_sfData-get-allProjects)
    foreach ($sitefinity in $sitefinities) {
        $sitefinity = [SfProject]$sitefinity
        if ($sitefinity.id -eq $name) {
            return $true;
        }
    }    

    return $false;
}

function _generateId {
    $i = 0;
    while ($true) {
        $name = "$($Script:idPrefix)$i"
        $isDuplicate = (_get-isIdDuplicate $name)
        if (-not $isDuplicate) {
            break;
        }
        
        $i++
    }

    if ([string]::IsNullOrEmpty($name) -or (-not (validate-nameSyntax $name))) {
        throw "Invalid id $name"
    }
    
    return $name
}

function set-currentProject {
    Param([SfProject]$newContext)

    _validate-project $newContext

    $script:globalContext = $newContext

    if ($newContext) {
        $ports = @(iis-get-websitePort $newContext.websiteName)
        if ($newContext.branch) {
            $branch = ($newContext.branch).split("4.0")[3]
        }
        else {
            $branch = '/no branch'
        }

        [System.Console]::Title = "$($newContext.displayName) ($($newContext.id)) $branch $ports "
        Set-Location $newContext.webAppPath
    }
    else {
        [System.Console]::Title = ""
    }
}

function _get-solutionFriendlyName {
    Param(
        [SfProject]$context
    )
    
    if (-not ($context)) {
        $context = _get-selectedProject
    }

    $solutionName = "$($context.displayName)($($context.id)).sln"
    
    return $solutionName
}

function _get-selectedProject {
    [OutputType([SfProject])]
    $currentContext = $script:globalContext
    if ($currentContext -eq '') {
        return $null
    }
    elseif ($null -eq $currentContext) {
        return $null
    }

    $context = $currentContext.PsObject.Copy()
    return [SfProject]$context
}

function validate-nameSyntax ($name) {
    return $name -match "^[A-Za-z]\w+$"
}

function _create-workspace ($context, $branch) {
    try {
        # create and map workspace
        Write-Host "Creating workspace..."
        $workspaceName = $context.id
        tfs-create-workspace $workspaceName $context.solutionPath
    }
    catch {
        throw "Could not create workspace $workspaceName in $($context.solutionPath).`n $_"
    }

    try {
        Write-Host "Creating workspace mappings..."
        tfs-create-mappings -branch $branch -branchMapPath $context.solutionPath -workspaceName $workspaceName
    }
    catch {
        throw "Could not create mapping $($branch) in $($context.solutionPath) for workspace ${workspaceName}.`n $_"
    }

    try {
        Write-Host "Getting latest workspace changes..."
        tfs-get-latestChanges -branchMapPath $context.solutionPath
    }
    catch {
        throw "Could not get latest workapce changes. $_"
    }
}