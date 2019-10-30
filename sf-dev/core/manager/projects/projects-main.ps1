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
        [Parameter(Mandatory = $true)][string]$sourcePath,
        [string]$displayName = 'Untitled'
    )

    if (!$sourcePath) {
        $sourcePath = _sf-proj-promptSourcePathSelect
    }

    [SfProject]$newContext = _newSfProjectObject
    $newContext.displayName = $displayName

    _createProjectFilesFromSource -sourcePath $sourcePath -project $newContext
    if (!$newContext.webAppPath) {
        throw "Error creating the project. The project failed to initialize with web app path."
    }

    _sf-proj-tags-setNewProjectDefaultTags -project $newContext
    _saveSelectedProject $newContext
    sf-proj-setCurrent $newContext        

    if (!$newContext.websiteName) {
        sf-iis-site-new
    }

    _createUserFriendlySlnName $newContext
    return $newContext
}

function sf-proj-clone {
    Param(
        [switch]$skipSourceControlMapping
    )

    $context = sf-proj-getCurrent

    $sourcePath = $context.solutionPath;
    $hasSolution = !([string]::IsNullOrEmpty($sourcePath));
    if (!$hasSolution) {
        $sourcePath = $context.webAppPath
    }

    if (!$sourcePath -or !(Test-Path $sourcePath)) {
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
        $errors = "Error copying source files.`n $_";
        try {
            Remove-Item $targetPath -Force -Recurse -ErrorVariable +errors -ErrorAction SilentlyContinue
        }
        finally {
            throw $errors
        }
    }

    [SfProject]$newProject = $null
    [SfProject]$newProject = _newSfProjectObject
    $newProject.displayName = "$($context.displayName)-clone"
    if ($hasSolution) {
        $newProject.solutionPath = $targetPath
        $newProject.webAppPath = "$targetPath\SitefinityWebApp"
        _createUserFriendlySlnName -context $newProject
    }
    else {
        $newProject.webAppPath = $targetPath
    }

    sf-proj-setCurrent -newContext $newProject

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
        sf-iis-site-new
    }
    catch {
        Write-Warning "Error during website creation. Message: $_"
        $newProject.websiteName = ""
    }

    $oldProject = $context
    $sourceDbName = _sf-app-db-getName $oldProject.webAppPath
    $isDuplicate = sql-test-isDbNameDuplicate -dbName $sourceDbName
    if ($sourceDbName -and $isDuplicate) {
        $newDbName = $newProject.id
        try {
            sf-app-db-setName $newDbName -context $newProject
        }
        catch {
            Write-Error "Error setting new database name in config $newDbName).`n $_"                    
        }
                
        try {
            sql-copy-db -SourceDBName $sourceDbName -targetDbName $newDbName
        }
        catch {
            Write-Error "Error copying old database. Source: $sourceDbName Target $newDbName`n $_"
        }
    }

    try {
        sf-app-states-removeAll
    }
    catch {
        Write-Error "Error deleting app states for $($newProject.displayName). Inner error:`n $_"        
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
function _sf-proj-tryUseExisting {
    
    Param(
        [Parameter(Mandatory = $true)][SfProject]$project,
        [Parameter(Mandatory = $true)][string]$path
    )

    
    if (Test-Path -Path "$path\SitefinityWebApp") {
        $path = "$path\SitefinityWebApp"
    }

    $isWebApp = Test-Path "$path\web.config"
    if (!$isWebApp) {
        return
    }

    $project.webAppPath = $path
    sf-proj-setCurrent $project
    _sf-proj-refreshData -project $project
    _saveSelectedProject $project
    return $true
}

function sf-proj-removeBulk {
    $sitefinities = @(sf-data-getAllProjects)
    if ($null -eq $sitefinities[0]) {
        Write-Host "No projects found. Create one."
        return
    }

    $sfsToDelete = _sf-proj-promptSfsSelection $sitefinities

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
    
    [SfProject]$currentProject = sf-proj-getCurrent
    $clearCurrentSelectedProject = $false
    if ($null -eq $context -or $currentProject.id -eq $context.id) {
        $context = $currentProject
        $clearCurrentSelectedProject = $true
    }
    
    # Del Website
    Write-Information "Deleting website..."
    $websiteName = $context.websiteName
    if ($websiteName -and (iis-test-isSiteNameDuplicate $websiteName)) {
        try {
            sf-iis-pool-stop $websiteName
        }
        catch {
            Write-Warning "Could not stop app pool: $_`n"            
        }

        try {
            _sf-iis-site-delete $context.websiteName
        }
        catch {
            Write-Warning "Errors deleting website ${websiteName}. $_`n"
        }
    }

    # TFS
    $workspaceName = $null
    try {
        Set-Location -Path $PSScriptRoot
        $workspaceName = tfs-get-workspaceName $context.webAppPath
    }
    catch {
        Write-Warning "No workspace to delete, no TFS mapping found."        
    }
    
    if ($workspaceName -and !($keepWorkspace)) {
        Write-Information "Deleting workspace..."
        try {
            tfs-delete-workspace $workspaceName $GLOBAL:Sf.Config.tfsServerName
        }
        catch {
            Write-Warning "Could not delete workspace $_"
        }
    }

    $dbName = _sf-app-db-getName -appPath $context.webAppPath

    # Del db
    if (-not [string]::IsNullOrEmpty($dbName) -and (-not $keepDb)) {
        Write-Information "Deleting sitefinity database..."
        
        try {
            sql-delete-database -dbName $dbName
        }
        catch {
            Write-Warning "Could not delete database: ${dbName}. $_"
        }
    }

    # Del dir
    if (!($keepProjectFiles)) {
        try {
            $solutionPath = $context.solutionPath
            if ($solutionPath) {
                $path = $solutionPath
            }
            else {
                $path = $context.webAppPath
            }
            
            Write-Information "Unlocking all locked files in solution directory..."
            unlock-allFiles -path $path

            Write-Information "Deleting solution directory..."
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
    
    if ($clearCurrentSelectedProject) {
        sf-proj-setCurrent $null
    }

    if (-not ($noPrompt)) {
        sf-proj-select
    }
}

function sf-proj-rename {
    Param(
        [string]$newName,
        [switch]$setDescription
    )

    $project = sf-proj-getCurrent
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
    $context.displayName = $newName

    if ($context.solutionPath) {
        if (-not (Test-Path "$($context.solutionPath)\$oldSolutionName")) {
            _createUserFriendlySlnName -context $context
        }
    
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
    }
    
    $domain = _generateDomainName -context $context
    _changeDomain -domainName $domain
    Set-Prompt -project $context
    
    _saveSelectedProject $context
}

<#
.SYNOPSIS
Undos all pending changes, gets latest, builds and initializes.
#>
function sf-proj-reset {
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
        sf-app-reset -start -rebuild -precompile
        sf-app-states-save -stateName initial
    }
}

function sf-proj-getCurrent {
    $currentContext = $Script:globalContext

    if ($null -eq $currentContext) {
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
        _validateProject $newContext        
    } 

    $Script:globalContext = $newContext
    Set-Prompt -project $newContext
}

function sf-proj-getAll {
    sf-data-getAllProjects
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
        $title = $title.Substring(0, $title.Length - 1)
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
        return
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

    if (!$context.id) {
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

function _getIsIdDuplicate ($id) {
    function _isDuplicate ($name) {
        if ($name -and $name.Contains($id)) {
            return $true
        }
        return $false
    }

    $sitefinities = [SfProject[]](sf-data-getAllProjects)
    $sitefinities | ForEach-Object {
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
    
    $dbs = sql-get-dbs | Where-Object { _isDuplicate $_.name }
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

function _sf-proj-refreshData {
    param (
        [Parameter(Mandatory = $true)][SfProject]$project
    )
    
    if ($project.isInitialized) {
        return
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

    _sf-proj-detectSolution -project $project
    _sf-proj-detectTfs -project $project
    _sf-proj-detectSite -project $project

    _saveSelectedProject -context $project
    $project.isInitialized = $true
}

function _createProjectFilesFromSource {
    param (
        [Parameter(Mandatory = $true)][Sfproject]$project,
        [Parameter(Mandatory = $true)][string]$sourcePath
    )
    
    $handled = _sf-proj-tryCreateFromBranch -project $project -sourcePath $sourcePath
    
    if (!$handled) {
        $handled = _sf-proj-tryCreateFromZip -project $project -sourcePath $sourcePath
    }

    if (!$handled) {
        $handled = _sf-proj-tryUseExisting -project $project -path $sourcePath
    }

    if (!$handled) {
        throw "Source path does not exist"
    }
}

function _sf-proj-createProjectDirectory {
    param (
        [Parameter(Mandatory = $true)][Sfproject]$project
    )
    
    Write-Information "Creating project files..."
    $projectDirectory = "$($GLOBAL:Sf.Config.projectsDirectory)\$($project.id)"
    if (Test-Path $projectDirectory) {
        throw "Path already exists:" + $projectDirectory
    }

    New-Item $projectDirectory -type directory > $null
    $projectDirectory
}

function _sf-proj-detectSolution ([SfProject]$project) {
    if (_sf-proj-isSolution -project $project) {
        $project.solutionPath = (Get-Item "$($project.webAppPath)\..\").Target
        _createUserFriendlySlnName $project
    }
    else {
        $project.solutionPath = ''
    }

    _saveSelectedProject -context $project
}

function _sf-proj-tryCreateFromBranch {
    param (
        [Parameter(Mandatory = $true)][Sfproject]$project,
        [Parameter(Mandatory = $true)][string]$sourcePath
    )

    if ($sourcePath.StartsWith("$/CMS/")) {
        $projectDirectory = _sf-proj-createProjectDirectory -project $project
        Write-Information "Creating project files..."
        $project.solutionPath = $projectDirectory;
        $project.webAppPath = "$projectDirectory\SitefinityWebApp";
        _createWorkspace -context $project -branch $sourcePath
        return $true
    }
}

function _sf-proj-tryCreateFromZip {
    param (
        [Parameter(Mandatory = $true)][Sfproject]$project,
        [Parameter(Mandatory = $true)][string]$sourcePath
    )

    if ($sourcePath.EndsWith('.zip') -and (Test-Path $sourcePath)) {
        $projectDirectory = _sf-proj-createProjectDirectory -project $project
        expand-archive -path $sourcePath -destinationpath $projectDirectory
        $isSolution = (Test-Path -Path "$projectDirectory/Telerik.Sitefinity.sln") -and (Test-Path "$projectDirectory/SitefinityWebApp")
        if ($isSolution) {
            $project.webAppPath = "$projectDirectory/SitefinityWebApp"
            $project.solutionPath = "$projectDirectory"
        }
        else {
            $project.webAppPath = "$projectDirectory"
        }

        return $true
    }
}

function _sf-proj-detectTfs ([SfProject]$project) {
    if (!(_sf-proj-isSolution -project $project)) {
        $project.branch = '';
        _saveSelectedProject -context $project
        return
    }

    $branch = tfs-get-branchPath -path $project.solutionPath
    if ($branch) {
        $project.branch = $branch
        _updateLastGetLatest -context $project
    }
    else {
        $project.branch = '';
        Write-Warning "Could not detect source control branch"
    }

    _saveSelectedProject -context $project
}

function _sf-proj-isSolution ([SfProject]$project) {
    Test-Path "$($project.webAppPath)\..\Telerik.Sitefinity.sln"
}

function _sf-proj-detectSite ([Sfproject]$project) {
    $siteName = iis-find-site -physicalPath $project.webAppPath
    if ($siteName) {
        $project.websiteName = $siteName
    }
    else {
        $project.websiteName = ''
        Write-Warning "$errorMessgePrefix Could not detect website for the current project."
    }
}