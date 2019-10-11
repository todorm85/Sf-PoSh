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
function sf-proj-new {
    
    Param(
        [string]$displayName,
        [switch]$buildSolution,
        [switch]$startWebApp,
        [switch]$precompile,
        [string]$sourcePath,
        [switch]$noAutoSelect
    )

    if (!$sourcePath) {
        while ($selectFrom -ne 1 -and $selectFrom -ne 2) {
            $selectFrom = Read-Host -Prompt "Create from?`n[1] Branch`n[2] Build`n"
        }

        $sourcePath = $null
        if ($selectFrom -eq 1) {
            $sourcePath = _promptPredefinedBranchSelect
        }
        else {
            $sourcePath = _promptPredefinedBuildPathSelect
        }
    }

    [SfProject]$newContext = _newSfProjectObject
    if (!$displayName) {
        $displayName = 'Untitled'
    }

    $newContext.displayName = $displayName

    $oldContext = sf-proj-getCurrent

    try {
        _createProjectFilesFromSource -sourcePath $sourcePath -project $newContext

        Write-Information "Creating website..."
        sf-iis-site-new -context $newContext

        _sf-proj-tags-setNewProjectDefaultTags -project $newContext

        _saveSelectedProject $newContext
    }
    catch {
        Write-Warning "############ CLEANING UP ############"
        Set-Location $PSScriptRoot
        
        try {
            Write-Information "Deleting workspace..."
            tfs-delete-workspace $newContext.id $GLOBAL:Sf.Config.tfsServerName
        }
        catch {
            Write-Warning "Error cleaning workspace or it was not created."
        }

        try {
            Write-Information "Deleting project files..."
            $path = $newContext.solutionPath
            if (!$path) {
                $path = $newContext.webAppPath
            }

            Remove-Item -Path $path -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError -Recurse
        }
        catch {
            Write-Warning "Error cleaning project directory or it was not created."
        }

        try {
            Write-Information "Removing website..."
            _deleteWebsite -context $newContext
        }
        catch {
            Write-Warning "Could not remove website or it was not created"
        }

        if ($oldContext) {
            sf-proj-setCurrent $oldContext
        }
        $ii = $_.InvocationInfo
        $msg = $_
        if ($ii) {
            $msg = "$msg`n$($ii.PositionMessage)"
        }

        throw $msg
    }

    try {
        sf-proj-setCurrent $newContext

        if ($buildSolution) {
            Write-Information "Building solution..."
            sf-sol-build -retryCount 3
        }

        if ($startWebApp) {
            try {
                Write-Information "Initializing Sitefinity"
                _createStartupConfig
                _startApp
                if ($precompile) {
                    sf-app-addPrecompiledTemplates
                }
            }
            catch {
                Write-Warning "APP WAS NOT INITIALIZED. $_"
                _deleteStartupConfig
            }
        }        
    }
    finally {
        if ($noAutoSelect) {
            sf-proj-setCurrent $oldContext
        }
    }

    return $newContext
}

function sf-proj-clone {
    Param(
        [SfProject]$context,
        [switch]$noAutoSelect,
        [switch]$skipSourceControlMapping
    )

    if (!$context) {
        $context = sf-proj-getCurrent
    }

    $sourcePath = $context.solutionPath;
    $hasSolution = !([string]::IsNullOrEmpty($sourcePath));
    if (!$hasSolution) {
        $sourcePath = $context.webAppPath
    }

    if ([string]::IsNullOrEmpty($sourcePath) -or -not (Test-Path $sourcePath)) {
        throw "Invalid app path";
    }

    $targetDirectoryName = [Guid]::NewGuid()
    $targetPath = $GLOBAL:Sf.Config.projectsDirectory + "\$targetDirectoryName"
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

    [SfProject]$newProject = $null
    try {
        [SfProject]$newProject = _newSfProjectObject
        $newProject.displayName = "$($context.displayName)-clone"
        if ($hasSolution) {
            $newProject.solutionPath = $targetPath
            $newProject.webAppPath = "$targetPath\SitefinityWebApp"
        }
        else {
            $newProject.webAppPath = $targetPath
        }
    }
    catch {
        Write-Warning "Cleaning up copied files"
        Remove-Item -Path $targetPath -Force -Recurse 
        throw "Error importing project.`n $_"
    }

    try {
        if (!$skipSourceControlMapping -and $context.branch) {
            _createWorkspace -context $newProject -branch $context.branch
        }
    }
    catch {
        Write-Error "Clone project error. Error binding to TFS.`n$_"
    }

    try {
        Write-Information "Creating website..."
        sf-iis-site-new -context $newProject > $null
    }
    catch {
        Write-Warning "Error during website creation. Message: $_"
        $newProject.websiteName = ""
    }

    $oldProject = $context
    $sourceDbName = _getCurrentAppDbName -project $oldProject
    
    if ($sourceDbName -and $tokoAdmin.sql.isDuplicate($sourceDbName)) {
        $newDbName = $newProject.id
        try {
            sf-app-db-setName $newDbName -context $newProject
        }
        catch {
            Write-Error "Error setting new database name in config $newDbName).`n $_"                    
        }
                
        try {
            $tokoAdmin.sql.CopyDb($sourceDbName, $newDbName)
        }
        catch {
            Write-Error "Error copying old database. Source: $sourceDbName Target $newDbName`n $_"
        }
    }

    try {
        sf-app-states-removeAll -context $newProject
    }
    catch {
        Write-Error "Error deleting app states for $($newProject.displayName). Inner error:`n $_"        
    }

    sf-proj-setCurrent -newContext $newProject
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
function sf-proj-import {
    
    Param(
        [Parameter(Mandatory = $true)][string]$displayName,
        [Parameter(Mandatory = $true)][string]$path
    )

    $isWebApp = Test-Path "$path\web.config"
    if (!$isWebApp) {
        throw "No asp.net web app found."
    }

    [SfProject]$newContext = _newSfProjectObject
    $newContext.displayName = $displayName
    $newContext.webAppPath = $path
    
    sf-proj-setCurrent $newContext
    _saveSelectedProject $newContext
    return $newContext
}

function sf-proj-removeBulk {
    $sitefinities = @(sf-data-getAllProjects)
    if ($null -eq $sitefinities[0]) {
        Write-Host "No projects found. Create one."
        return
    }

    sf-proj-showAll $sitefinities

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
            sf-proj-remove -context $selectedSitefinity -noPrompt
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
function sf-proj-remove {
    Param(
        [switch]$keepDb,
        [switch]$keepWorkspace,
        [switch]$keepProjectFiles,
        [switch]$noPrompt,
        [SfProject]$context = $null
    )
    
    if ($null -eq $context) {
        $context = sf-proj-getCurrent
    }

    _initializeProject -suppressWarnings -project $context

    $solutionPath = $context.solutionPath
    $workspaceName = $null
    try {
        $workspaceName = tfs-get-workspaceName $context.webAppPath
    }
    catch {
        Write-Warning "No workspace to delete, no TFS mapping found."        
    }

    $dbName = sf-app-db-getName $context
    $websiteName = $context.websiteName
    
    if ($websiteName) {
        try {
            sf-iis-pool-stop -context $context
        }
        catch {
            Write-Warning "Could not stop app pool: $_"            
        }
    }

    Set-Location -Path $PSScriptRoot

    # Del workspace
    if ($workspaceName -and !($keepWorkspace)) {
        Write-Information "Deleting workspace..."
        try {
            tfs-delete-workspace $workspaceName $GLOBAL:Sf.Config.tfsServerName
        }
        catch {
            Write-Warning "Could not delete workspace $_"
        }
    }

    # Del db
    if (-not [string]::IsNullOrEmpty($dbName) -and (-not $keepDb)) {
        Write-Information "Deleting sitefinity database..."
        
        try {
            $tokoAdmin.sql.Delete($dbName)
        }
        catch {
            Write-Warning "Could not delete database: ${dbName}. $_"
        }
    }

    # Del Website
    Write-Information "Deleting website..."
    if ($websiteName) {
        try {
            _deleteWebsite $context
        }
        catch {
            Write-Warning "Errors deleting website ${websiteName}. $_"
        }
    }

    # Del dir
    if (!($keepProjectFiles)) {
        try {
            Write-Information "Unlocking all locked files in solution directory..."
            sf-sol-unlockAllFiles

            Write-Information "Deleting solution directory..."
            if ($solutionPath -ne "") {
                $path = $solutionPath
            }
            else {
                $path = $context.webAppPath
            }

            Remove-Item $path -recurse -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            if ($ProcessError) {
                throw $ProcessError
            }
        }
        catch {
            Write-Warning "Errors deleting sitefinity directory. $_"
        }
    }

    Write-Information "Deleting data entry..."
    try {
        _removeProjectData $context
    }
    catch {
        Write-Warning "Could not remove the project entry from the tool. You can manually remove it at $($GLOBAL:Sf.Config.dataPath)"
    }
    
    sf-proj-setCurrent $null

    if (-not ($noPrompt)) {
        sf-proj-select
    }
}

function sf-proj-rename {
    
    Param(
        [string]$newName,
        [switch]$setDescription,
        [SfProject]$project
    )

    if (!$project) {
        $project = sf-proj-getCurrent
    }

    [SfProject]$context = $project

    if (-not $newName) {
        while ([string]::IsNullOrEmpty($newName)) {
            if ($newName) {
                Write-Warning "Invalid name syntax."
            }

            $newName = $(Read-Host -Prompt "Enter new project name").ToString()
        }

        if ($setDescription) {
            $context.description = $(Read-Host -Prompt "Enter description:`n").ToString()
        }
    }

    $azureDevOpsResult = _getAzureDevOpsTitleAndLink $newName
    $newName = $azureDevOpsResult.name
    $context.description = $azureDevOpsResult.link

    if ($newName -and (-not (_validateNameSyntax $newName))) {
        Write-Error "Name syntax is not valid. Use only alphanumerics and underscores"
    }

    $oldSolutionName = _generateSolutionFriendlyName -context $context
    if (-not (Test-Path "$($context.solutionPath)\$oldSolutionName")) {
        _createUserFriendlySlnName -context $context
    }

    $context.displayName = $newName

    $newSolutionName = _generateSolutionFriendlyName -context $context
    $oldSolutionPath = "$($context.solutionPath)\$oldSolutionName"
    if (Test-Path $oldSolutionPath) {
        Copy-Item -Path $oldSolutionPath -Destination "$($context.solutionPath)\$newSolutionName" -Force
        
        $newSlnCacheName = ([string]$newSolutionName).Replace(".sln", "")
        $oldSlnCacheName = ([string]$oldSolutionName).Replace(".sln", "")
        $oldSolutionCachePath = "$($context.solutionPath)\.vs\$oldSlnCacheName"
        if (Test-Path $oldSolutionCachePath) {
            Copy-Item -Path $oldSolutionCachePath -Destination "$($context.solutionPath)\.vs\$newSlnCacheName" -Force -Recurse -ErrorAction SilentlyContinue
            unlock-allFiles -path $oldSolutionCachePath
            Remove-Item -Path $oldSolutionCachePath -Force -Recurse
        }

        unlock-allFiles -path $oldSolutionPath
        Remove-Item -Path $oldSolutionPath -Force
    }
    
    $domain = _generateDomainName -context $context
    _changeDomain -context $context -domainName $domain
    
    _saveSelectedProject $context
    sf-proj-setCurrent -newContext $context 
}

<#
.SYNOPSIS
Undos all pending changes, gets latest, builds and initializes.
#>
function sf-proj-reset {
    param(
        [SfProject]
        $project
    )

    if (-not $project) {
        $project = sf-proj-getCurrent
    }

    if ($project.lastGetLatest -and [System.DateTime]::Parse($project.lastGetLatest) -lt [System.DateTime]::Today) {
        $shouldReset = $false
        if (sf-tfs-hasPendingChanges) {
            sf-tfs-undoPendingChanges
            $shouldReset = $true
        }

        $getLatestOutput = sf-tfs-getLatestChanges -overwrite
        if (-not ($getLatestOutput.Contains('All files are up to date.'))) {
            $shouldReset = $true
        }

        if ($shouldReset) {
            sf-sol-clean -cleanPackages $true
            sf-app-reset -start -build -precompile
            sf-app-states-save -stateName initial
        }
    }
}

function sf-proj-getCurrent {
    [OutputType([SfProject])]
    $currentContext = $Script:globalContext
    if ($currentContext -eq '') {
        return $null
    }
    elseif ($null -eq $currentContext) {
        return $null
    }

    $context = $currentContext.PsObject.Copy()
    return [SfProject]$context
}

function sf-proj-setCurrent {
    Param(
        [SfProject]$newContext
    )
        
    if ($null -ne $newContext) {
        _initializeProject $newContext
        _validateProject $newContext        
    } 

    $Script:globalContext = $newContext
    _setConsoleTitle -newContext $newContext
    Set-Prompt -project $newContext
}

function _getAzureDevOpsTitleAndLink {
    Param([string]$name)
    $description = ''
    $titleKeys = @("Product Backlog Item ", "Bug ", "Task ");
    foreach ($key in $titleKeys) {
        if ($name.StartsWith($key)) {
            $name = $name.Replace($key, '');
            $nameParts = $name.Split(':');
            $itemId = $nameParts[0].Trim();
            $title = $nameParts[1].Trim();
            $resultTitle = ''
            for ($i = 0; $i -lt $name.Length; $i++) {
                $resultTitle = "${resultTitle}:$($title[$i])";
            }
            
            $name = $name.Trim();
            $name = _getValidTitle $name

            $description = "https://prgs-sitefinity.visualstudio.com/sitefinity/_workitems/edit/$itemId"
        }
    }

    return @{ name = $name; link = $description }
}

function _getValidTitle {
    param (
        [string]$title
    )

    $validStartEnd = "^[A-Za-z]$";
    $validMiddle = "^\w$";
    while (!($title[0] -match $validStartEnd)) {
        $title = $title.Substring(1)
    }

    while (!($title[$title.Length - 1] -match $validStartEnd)) {
        $title = $title.Substring($title.Length - 2)
    }

    $resultTitle = '';
    for ($i = 0; $i -lt $title.Length; $i++) {
        if ($title[$i] -match $validMiddle) {
            $resultTitle = "$resultTitle$($title[$i])"
        }
        elseif ($title[$i] -eq ' ') {
            $resultTitle = "${resultTitle}_"
        }
    }

    if ($resultTitle.Length -ge 51) {
        $resultTitle = $resultTitle.Remove(50);
    }
    
    return $resultTitle;
}

function _createUserFriendlySlnName ($context) {
    $solutionFilePath = "$($context.solutionPath)\Telerik.Sitefinity.sln"
    if (!(Test-Path $solutionFilePath)) {
        Write-Warning "Solution file not available."    
    }

    $targetFilePath = "$($context.solutionPath)\$(_generateSolutionFriendlyName $context)"
    if (!(Test-Path $targetFilePath)) {
        Copy-Item -Path $solutionFilePath -Destination $targetFilePath
    }
}

function _saveSelectedProject {
    Param($context)

    _validateProject $context

    _setProjectData $context
}

function _validateProject {
    Param($context)

    if ($null -ne $context) {
        if ($context.id -eq '') {
            throw "Invalid sitefinity context. No sitefinity id."
        }

        if ($context.solutionPaths) {
            if (-not (Test-Path $context.solutionPath)) {
                throw "Invalid sitefinity context. Solution path does not exist."
            }
        }
        
        if (-not ($context.webAppPath -and (Test-Path $context.webAppPath))) {
            throw "Invalid sitefinity context. No web app path or it does not exist."
        }
    }
}

function _getIsIdDuplicate ($id) {
    function _isDuplicate ($name) {
        if ($name -and $name.Contains($id)) {
            return $true
        }
        return $false
    }

    $sitefinities = [SfProject[]](sf-data-getAllProjects)
    $sitefinities | % {
        $sitefinity = [SfProject]$_
        if ($sitefinity.id -eq $id) {
            return $true;
        }
    }

    if (Test-Path "$($GLOBAL:Sf.Config.projectsDirectory)\$id") { return $true }

    $wss = tfs-get-workspaces $GLOBAL:Sf.Config.tfsServerName | Where-Object { _isDuplicate $_ }
    if ($wss) { return $true }

    Import-Module WebAdministration
    $sites = Get-Item "IIS:\Sites"
    if ($sites -and $sites.Children) {
        $names = $sites.Children.Keys | Where-Object { _isDuplicate $_ }
        if ($names) { return $true }
    }
    $pools = Get-Item "IIS:\AppPools"
    if ($pools -and $pools.Children) {
        $names = $pools.Children.Keys | Where-Object { _isDuplicate $_ }
        if ($names) { return $true }
    }
    
    $dbs = $tokoAdmin.sql.GetDbs() | Where-Object { _isDuplicate $_.name }
    if ($dbs) { return $true }

    return $false;
}

function _generateId {
    $i = 0;
    while ($true) {
        $name = "$($GLOBAL:Sf.Config.idPrefix)$i"
        $_isDuplicate = (_getIsIdDuplicate $name)
        if (-not $_isDuplicate) {
            break;
        }
        
        $i++
    }

    if ([string]::IsNullOrEmpty($name) -or (-not (_validateNameSyntax $name))) {
        throw "Invalid id $name"
    }
    
    return $name
}

function _setConsoleTitle {
    param (
        [SfProject]$newContext
    )

    if ($newContext) {
        $ports = @(iis-get-websitePort $newContext.websiteName)
        if ($newContext.branch) {
            $branch = ($newContext.branch).Split([string[]]("$/CMS/Sitefinity 4.0"), [System.StringSplitOptions]::RemoveEmptyEntries)[0]
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

function _generateSolutionFriendlyName {
    Param(
        [SfProject]$context
    )
    
    if (-not ($context)) {
        $context = sf-proj-getCurrent
    }

    $solutionName = "$($context.displayName)($($context.id)).sln"
    
    return $solutionName
}

function _validateNameSyntax ($name) {
    return $name -match "^[A-Za-z]\w+$" -and $name.Length -lt 75
}

function _createWorkspace ($context, $branch) {
    try {
        # create and map workspace
        Write-Information "Creating workspace..."
        $workspaceName = $context.id
        tfs-create-workspace $workspaceName $context.solutionPath $GLOBAL:Sf.Config.tfsServerName
    }
    catch {
        throw "Could not create workspace $workspaceName in $($context.solutionPath).`n $_"
    }

    try {
        Write-Information "Creating workspace mappings..."
        tfs-create-mappings -branch $branch -branchMapPath $context.solutionPath -workspaceName $workspaceName -server $GLOBAL:Sf.Config.tfsServerName
    }
    catch {
        throw "Could not create mapping $($branch) in $($context.solutionPath) for workspace ${workspaceName}.`n $_"
    }

    try {
        Write-Information "Getting latest workspace changes..."
        tfs-get-latestChanges -branchMapPath $context.solutionPath -overwrite > $null
        $context.branch = $branch
        $context.lastGetLatest = [DateTime]::Today
        _saveSelectedProject $context
    }
    catch {
        throw "Could not get latest workapce changes. $_"
    }
}

function _initializeProject {
    param (
        [Parameter(Mandatory = $true)][SfProject]$project,
        [switch]$suppressWarnings
    )
    
    if ($project.isInitialized) {
        return
    }

    $oldWarningPreference = $WarningPreference
    if ($suppressWarnings) {
        $WarningPreference = 'SilentlyContinue'
    }

    if (!$project.displayName -or !$project.id) {
        if (!$suppressWarnings) {
            throw "Cannot initialize a project with no display name or id. Check tool database at $($GLOBAL:Sf.config.dataPath)"    
        }
    }

    $errorMessgePrefix = "ERROR Working with project $($project.displayName) in $($project.webAppPath) and id $($project.id)."

    if (!(Test-Path $project.webAppPath)) {
        if (!$suppressWarnings) {
            throw "$errorMessgePrefix $($project.webAppPath) does not exist."
        }
        else {
            return
        }
    }

    $isSolution = Test-Path "$($project.webAppPath)\..\Telerik.Sitefinity.sln"
    if ($isSolution) {
        $project.solutionPath = (Get-Item "$($project.webAppPath)\..\").Target
        _createUserFriendlySlnName $project
        
        $branch = tfs-get-branchPath -path $project.solutionPath
        if ($branch) {
            $project.branch = $branch
            _updateLastGetLatest -context $project
        }
        else {
            Write-Warning "$errorMessgePrefix Could not detect source control branch, TFS related function_aliuty for the project will not work."
        }
    }
        
    $siteName = iis-find-site -physicalPath $project.webAppPath
    if ($siteName) {
        $project.websiteName = $siteName
    }
    else {
        Write-Warning "$errorMessgePrefix Could not detect website for the current project."
    }

    _saveSelectedProject -context $project
    $project.isInitialized = $true

    $WarningPreference = $oldWarningPreference
}

function _createProjectFilesFromSource {
    param (
        [Parameter(Mandatory = $true)][Sfproject]$project,
        [Parameter(Mandatory = $true)][string]$sourcePath
    )
    
    $projectDirectory = "$($GLOBAL:Sf.Config.projectsDirectory)\$($project.id)"
    if (Test-Path $projectDirectory) {
        throw "Path already exists:" + $projectDirectory
    }

    New-Item $projectDirectory -type directory > $null

    if ($sourcePath.StartsWith("$/CMS/")) {
        Write-Information "Creating project files..."
        $project.solutionPath = $projectDirectory;
        $project.webAppPath = "$projectDirectory\SitefinityWebApp";
        _createWorkspace -context $project -branch $sourcePath
    }
    else {
        if (!($sourcePath.EndsWith('.zip'))) {
            $sourcePath = "$sourcePath\SitefinityWebApp.zip"
        }

        if (!(Test-Path -Path $sourcePath)) {
            throw "Source path does not exist $sourcePath or is unreachable."
        }

        expand-archive -path $sourcePath -destinationpath $projectDirectory
        $isSolution = (Test-Path -Path "$projectDirectory/Telerik.Sitefinity.sln") -and (Test-Path "$projectDirectory/SitefinityWebApp")
        if ($isSolution) {
            $project.webAppPath = "$projectDirectory/SitefinityWebApp"
            $project.solutionPath = "$projectDirectory"
        }
        else {
            $project.webAppPath = "$projectDirectory"
        }
    }
}
