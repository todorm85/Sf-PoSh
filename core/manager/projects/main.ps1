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

        $defaultContext = _sf-get-newProject -displayName $displayName
        # $defaultContext.
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
            $workspaceName = $defaultContext.name
            tfs-create-workspace $workspaceName $defaultContext.solutionPath

            Write-Host "Creating workspace mappings..."
            tfs-create-mappings -branch $branch -branchMapPath $defaultContext.solutionPath -workspaceName $workspaceName
            $newContext.branch = $branch

            Write-Host "Getting latest workspace changes..."
            tfs-get-latestChanges -branchMapPath $defaultContext.solutionPath

            $webAppPath = $defaultContext.solutionPath + '\SitefinityWebApp'
            $newContext.webAppPath = $webAppPath
            $newContext.containerName = $defaultContext.containerName

            Write-Host "Backing up original App_Data folder..."
            $originalAppDataSaveLocation = "$webAppPath/sf-dev-tool/original-app-data"
            New-Item -Path $originalAppDataSaveLocation -ItemType Directory > $null
            Copy-Item -Path "$webAppPath\App_Data\*" -Destination $originalAppDataSaveLocation -Recurse > $null

            # persist current context to script data
            $oldContext = _get-selectedProject
            _sf-set-currentProject $newContext
            _save-selectedProject $newContext
        }
        catch {
            Write-Warning "############ CLEANING UP ############"
            Set-Location $PSScriptRoot
        
            try {
                Write-Host "Deleting workspace..."
                tfs-delete-workspace $workspaceName
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
                _sf-set-currentProject $oldContext
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

        _create-userFriendlySolutionName $defaultContext

        if ($buildSolution) {
            try {
                Write-Host "Building solution..."
                $tries = 0
                $retryCount = 3
                while ($tries -lt $retryCount) {
                    $tries++
                    try {
                        sf-build-solution
                    }
                    catch {
                        Write-Host "Build failed."
                        if ($tries > 0) {
                            Write-Host "Retrying..." 
                        }
                        else { throw "Solution could not build after $retryCount retries" }
                    }
                }
            }
            catch {
                $startWebApp = $false
                Write-Warning "SOLUTION WAS NOT BUILT. Message: $_"
            }
        }
            
        try {
            Write-Host "Creating website..."
            _sf-create-website -newWebsiteName $defaultContext.websiteName
        }
        catch {
            $startWebApp = $false
            Write-Warning "Error creating website. Message: $_"
        }

        if ($startWebApp) {
            try {
                Write-Host "Initializing Sitefinity"
                _sf-create-startupConfig
                _sf-start-app
                if ($precompile) {
                    sf-add-precompiledTemplates
                }
            }
            catch {
                Write-Warning "APP WAS NOT INITIALIZED. $_"
                _sf-delete-startupConfig
            }
        }        

        # Display message
        os-popup-notification "Operation completed!"
    }
}

function sf-clone-project {
    $context = _get-selectedProject
    $sourcePath = $context.solutionPath 
    if (-not (Test-Path $sourcePath)) {
        $sourcePath = $context.webAppPath
    }

    $targetName = "$($context.name)_clone"
    $targetPath = $script:projectsDirectory + "\${targetName}_0"
    $i = 0
    while (Test-Path $targetPath) {
        $i++
        $targetPath = "$($script:projectsDirectory)\$($targetName)_$i"
    }

    New-Item $targetPath -ItemType Directory > $null
    Copy-Item "${sourcePath}\*" $targetPath -Recurse
    sf-import-project -displayName "$($context.displayName)-clone_$i" -path $targetPath -name "$($targetName)_$i"
    sf-delete-allAppStates
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
        [string]$name
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

    $oldContext = _get-selectedProject
    $defaultContext = _sf-get-newProject $displayName $name
    $newContext = @{ name = $defaultContext.name }
    $newContext.displayName = $defaultContext.displayName
    if ($isSolution) {
        $newContext.solutionPath = $path
        $newContext.webAppPath = $path + '\SitefinityWebApp'
        _create-userFriendlySolutionName $newContext
    }
    else {
        $newContext.solutionPath = ''
        $newContext.webAppPath = $path
    }

    _sf-set-currentProject $newContext

    try {
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
        }
        else {
            try {
                Write-Host "Creating website..."
            
                $isDuplicateSite = $true
                while ($isDuplicateSite) {
                    $isDuplicateSite = iis-test-isSiteNameDuplicate $defaultContext.websiteName
                    if ($isDuplicateSite) {
                        $defaultContext.websiteName = Read-Host -Prompt "Enter site name"
                    }
                }

                _sf-create-website -newWebsiteName $defaultContext.websiteName > $null
                $newContext.websiteName = $defaultContext.websiteName
            }
            catch {
                Write-Warning "Error during website creation. Message: $_"
            }
        }

        $oldDbName = sf-get-appDbName
        if ($oldDbName) {
            while ($useCopy -ne 'y' -and $useCopy -ne 'n') {
                $useCopy = Read-Host -Prompt 'Clone existing database? [y/n]'
            }

            if ($useCopy -eq 'y') {
                sf-set-appDbName $newContext.name
                sql-copy-db $oldDbName $newContext.name
            }
        }

        _save-selectedProject $newContext

        # Display message
        os-popup-notification "Operation completed!"
    }
    catch {
        Write-Host "Could not import sitefinity: $($_)"
        sf-delete-project
        _sf-set-currentProject $oldContext
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
        [switch]$keepWorkspace,
        [switch]$keepProjectFiles,
        [switch]$force,
        [SfProject]$context = $null
    )
    
    if ($null -eq $context) {
        $context = _get-selectedProject
    }

    $solutionPath = $context.solutionPath
    $workspaceName = tfs-get-workspaceName $context.webAppPath
    $dbName = sf-get-appDbName
    $websiteName = $context.websiteName
    
    if ($websiteName) {
        sf-stop-pool
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
            Write-Host "Could not delete workspace $_.Exception.Message"
        }
    }

    # Del db
    if (-not [string]::IsNullOrEmpty($dbName)) {
        Write-Host "Deleting sitefinity database..."
        try {
            sql-delete-database -dbName $dbName
        }
        catch {
            Write-Host "Could not delete database: ${dbName}. $_.Exception.Message"
        }
    }

    # Del Website
    Write-Host "Deleting website..."
    if ($websiteName) {
        try {
            _sf-delete-website
        }
        catch {
            Write-Host "Errors deleting website ${websiteName}. $_.Exception.Message"
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
            Write-Host "Errors deleting sitefinity directory. $_.Exception.Message"
        }
    }

    Write-Host "Deleting data entry..."
    _sfData-delete-project $context
    _sf-set-currentProject $null

    # Display message
    os-popup-notification -msg "Operation completed!"
}

function _create-userFriendlySolutionName ($context) {
    $solutionFilePath = "$($context.solutionPath)\Telerik.Sitefinity.sln"
    $targetFilePath = "$($context.solutionPath)\$(_get-solutionFriendlyName $context)"
    Copy-Item -Path $solutionFilePath -Destination $targetFilePath
}

function _save-selectedProject {
    Param($context)

    _validate-project $context

    _sfData-save-project $context

    _sf-set-currentProject $context
}

function _validate-project {
    Param($context)

    if ($null -ne $context) {
        if ($context.name -eq '') {
            throw "Invalid sitefinity context. No sitefinity name."
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

function _sf-get-newProject {
    [OutputType([SfProject])]
    Param(
        [string]$displayName,
        [string]$name
    )
        
    function applyContextConventions {
        Param(
            $defaultContext
        )

        $name = $defaultContext.name
        $solutionPath = "${projectsDirectory}\${name}";
        $webAppPath = "${projectsDirectory}\${name}\SitefinityWebApp";
        $websiteName = $name

        $defaultContext.solutionPath = $solutionPath
        $defaultContext.webAppPath = $webAppPath
        $defaultContext.websiteName = $websiteName
        $defaultContext.containerName = $Script:selectedContainer.name
    }

    function isNameDuplicate ($name) {
        $sitefinities = [SfProject[]]@(_sfData-get-allProjects)
        foreach ($sitefinity in $sitefinities) {
            $sitefinity = [SfProject]$sitefinity
            if ($sitefinity.name -eq $name) {
                return $true;
            }
        }    

        return $false;
    }

    function validateName ($context) {
        $name = $context.name
        while ($true) {
            $isDuplicate = (isNameDuplicate $name)
            $isValid = _sf-validate-nameSyntax $name
            if (-not $isValid) {
                Write-Host "Sitefinity name must contain only alphanumerics and not start with number."
                $name = Read-Host "Enter new name: "
            }
            elseif ($isDuplicate) {
                Write-Host "Duplicate sitefinity naem."
                $name = Read-Host "Enter new name: "
            }
            else {
                $context.name = $name
                break
            }
        }
    }

    if ([string]::IsNullOrEmpty($name)) {
        $name = _generateId    
    }
    
    $defaultContext = New-Object SfProject -Property @{
        displayName  = $displayName;
        name         = $name;
        solutionPath = '';
        webAppPath   = '';
        websiteName  = '';
    }

    validateName $defaultContext

    applyContextConventions $defaultContext

    return $defaultContext
}

function _generateId {
    $i = 0;
    while ($true) {
        $name = "instance_$i"
        $isDuplicate = (isNameDuplicate $name)
        if (-not $isDuplicate) {
            break;
        }
        
        $i++
    }

    return $name
}

function _sf-set-currentProject {
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

        [System.Console]::Title = "$($newContext.displayName) ($($newContext.name)) $branch $ports "
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

    $solutionName = "$($context.displayName)($($context.name)).sln"
    
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

function _sf-validate-nameSyntax ($name) {
    return $name -match "^[A-Za-z-0-9_]+$"
}
