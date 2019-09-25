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
function New-Project {
    
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
            $selectFrom = Read-Host -Prompt "Create from?`n1.Branch`n2.Build"
        }

        $sourcePath = $null
        if ($selectFrom -eq 1) {
            $sourcePath = PromptPredefinedBranchSelect
        }
        else {
            $sourcePath = PromptPredefinedBuildPathSelect
        }
    }

    [SfProject]$newContext = NewObjectSfProject
    if (!$displayName) {
        $displayName = 'Untitled'
    }

    $newContext.displayName = $displayName

    $oldContext = Get-CurrentProject

    try {
        CreateProjectFilesFromSource -sourcePath $sourcePath -project $newContext 

        Write-Information "Backing up original App_Data folder..."
        $webAppPath = $newContext.webAppPath
        $originalAppDataSaveLocation = "$webAppPath/sf-dev-tool/original-app-data"
        New-Item -Path $originalAppDataSaveLocation -ItemType Directory > $null
        CopySfRuntimeFiles -project $newContext -dest $originalAppDataSaveLocation

        Write-Information "Creating website..."
        New-Website -context $newContext

        SaveSelectedProject $newContext
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
            DeleteWebsite -context $newContext
        }
        catch {
            Write-Warning "Could not remove website or it was not created"
        }

        if ($oldContext) {
            SetCurrentProject $oldContext
        }
        $ii = $_.InvocationInfo
        $msg = $_
        if ($ii) {
            $msg = "$msg`n$($ii.PositionMessage)"
        }

        throw $msg
    }

    try {
        SetCurrentProject $newContext

        if ($buildSolution) {
            Write-Information "Building solution..."
            Start-SolutionBuild -retryCount 3
        }

        if ($startWebApp) {
            try {
                Write-Information "Initializing Sitefinity"
                CreateStartupConfig
                StartApp
                if ($precompile) {
                    Add-PrecompiledTemplates
                }
            }
            catch {
                Write-Warning "APP WAS NOT INITIALIZED. $_"
                DeleteStartupConfig
            }
        }        
    }
    finally {
        if ($noAutoSelect) {
            SetCurrentProject $oldContext
        }
    }

    return $newContext
}

function Copy-Project {
    Param(
        [SfProject]$context,
        [switch]$noAutoSelect,
        [switch]$skipSourceControlMapping
    )

    if (!$context) {
        $context = Get-CurrentProject
    }

    $sourcePath = $context.solutionPath;
    if ([string]::IsNullOrEmpty($sourcePath)) {
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
        [SfProject]$newProject = NewObjectSfProject
        $newProject.displayName = "$($context.displayName)-clone"
        $newProject.webAppPath = "$targetPath\SitefinityWebApp"
    }
    catch {
        Write-Warning "Cleaning up copied files"
        Remove-Item -Path $targetPath -Force -Recurse 
        throw "Error importing project.`n $_"
    }

    try {
        if (!$skipSourceControlMapping -and $context.branch) {
            CreateWorkspace -context $newProject -branch $context.branch
        }
    }
    catch {
        Write-Error "Clone project error. Error binding to TFS.`n$_"
    }

    try {
        Write-Information "Creating website..."
        New-Website -context $newProject > $null
    }
    catch {
        Write-Warning "Error during website creation. Message: $_"
        $newProject.websiteName = ""
    }

    $oldProject = $context
    $sourceDbName = GetCurrentAppDbName -project $oldProject
    
    if ($sourceDbName -and $tokoAdmin.sql.isDuplicate($sourceDbName)) {
        $newDbName = $newProject.id
        try {
            Set-AppDbName $newDbName -context $newProject
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
        Remove-AllAppStates -context $newProject
    }
    catch {
        Write-Error "Error deleting app states for $($newProject.displayName). Inner error:`n $_"        
    }

    SetCurrentProject -newContext $newProject
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
function Import-Project {
    
    Param(
        [Parameter(Mandatory = $true)][string]$displayName,
        [Parameter(Mandatory = $true)][string]$path
    )

    $isWebApp = Test-Path "$path\web.config"
    if (!$isWebApp) {
        throw "No asp.net web app found."
    }

    [SfProject]$newContext = NewObjectSfProject
    $newContext.displayName = $displayName
    $newContext.webAppPath = $path
    
    SetCurrentProject $newContext
    SaveSelectedProject $newContext
    return $newContext
}

function Remove-ManyProjects {
    $sitefinities = @(Get-AllProjects)
    if ($null -eq $sitefinities[0]) {
        Write-Host "No projects found. Create one."
        return
    }

    Show-Projects $sitefinities

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
            Remove-Project -context $selectedSitefinity -noPrompt
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
function Remove-Project {
    
    Param(
        [switch]$keepDb,
        [switch]$keepWorkspace,
        [switch]$keepProjectFiles,
        [switch]$noPrompt,
        [SfProject]$context = $null
    )
    
    if ($null -eq $context) {
        $context = Get-CurrentProject
    }

    $solutionPath = $context.solutionPath
    $workspaceName = $null
    try {
        $workspaceName = tfs-get-workspaceName $context.webAppPath
    }
    catch {
        Write-Warning "No workspace to delete, no TFS mapping found."        
    }

    $dbName = Get-AppDbName $context
    $websiteName = $context.websiteName
    
    if ($websiteName) {
        try {
            Stop-Pool -context $context
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
            DeleteWebsite $context
        }
        catch {
            Write-Warning "Errors deleting website ${websiteName}. $_"
        }
    }

    # Del dir
    if (!($keepProjectFiles)) {
        try {
            Write-Information "Unlocking all locked files in solution directory..."
             Unlock-AllProjectFiles

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
        RemoveProjectData $context
    }
    catch {
        Write-Warning "Could not remove the project entry from the tool. You can manually remove it at $($GLOBAL:Sf.Config.dataPath)"
    }
    
    SetCurrentProject $null

    if (-not ($noPrompt)) {
        Select-Project
    }
}

function Rename-Project {
    
    Param(
        [string]$newName,
        [switch]$setDescription,
        [SfProject]$project
    )

    if (!$project) {
        $project = Get-CurrentProject
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

    $azureDevOpsResult = Get-AzureDevOpsTitleAndLink $newName
    $newName = $azureDevOpsResult.name
    $context.description = $azureDevOpsResult.link

    if ($newName -and (-not (ValidateNameSyntax $newName))) {
        Write-Error "Name syntax is not valid. Use only alphanumerics and underscores"
    }

    $oldSolutionName = GenerateSolutionFriendlyName -context $context
    if (-not (Test-Path "$($context.solutionPath)\$oldSolutionName")) {
        CreateUserFriendlySlnName -context $context
    }

    $context.displayName = $newName

    $newSolutionName = GenerateSolutionFriendlyName -context $context
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
    
    $domain = GenerateDomainName -context $context
    ChangeDomain -context $context -domainName $domain
    
    SaveSelectedProject $context
    SetCurrentProject -newContext $context 
}

<#
.SYNOPSIS
Undos all pending changes, gets latest, builds and initializes.
#>
function Reset-Project {
    param(
        [SfProject]
        $project
    )

    if (-not $project) {
        $project = Get-CurrentProject
    }

    if ($project.lastGetLatest -and [System.DateTime]::Parse($project.lastGetLatest) -lt [System.DateTime]::Today) {
        $shouldReset = $false
        if (Get-HasPendingChanges) {
            Undo-PendingChanges
            $shouldReset = $true
        }

        $getLatestOutput = Get-LatestChanges -overwrite
        if (-not ($getLatestOutput.Contains('All files are up to date.'))) {
            $shouldReset = $true
        }

        if ($shouldReset) {
            Start-SolutionClean -cleanPackages $true
            Reset-App -start -build -precompile
            Save-AppState -stateName initial
        }
    }
}

function Get-CurrentProject {
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

function Open-Description {
    $context = Get-CurrentProject
    if ($context.description -and $context.description.StartsWith("https://")) {
        $browserPath = $GLOBAL:Sf.Config.browserPath;
        execute-native "& `"$browserPath`" `"$($context.description)`" -noframemerging" -successCodes @(100)
    } else {
        $context.description
    }
}

function CreateUserFriendlySlnName ($context) {
    $solutionFilePath = "$($context.solutionPath)\Telerik.Sitefinity.sln"
    if (!(Test-Path $solutionFilePath)) {
        Write-Warning "Solution file not available."    
    }

    $targetFilePath = "$($context.solutionPath)\$(GenerateSolutionFriendlyName $context)"
    if (!(Test-Path $targetFilePath)) {
        Copy-Item -Path $solutionFilePath -Destination $targetFilePath
    }
}

function SaveSelectedProject {
    Param($context)

    ValidateProject $context

    SetProjectData $context
}

function ValidateProject {
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

function GetIsIdDuplicate ($id) {
    function IsDuplicate ($name) {
        if ($name -and $name.Contains($id)) {
            return $true
        }
        return $false
    }

    $sitefinities = [SfProject[]](Get-AllProjects -skipInit)
    $sitefinities | % {
        $sitefinity = [SfProject]$_
        if ($sitefinity.id -eq $id) {
            return $true;
        }
    }

    if (Test-Path "$($GLOBAL:Sf.Config.projectsDirectory)\$id") { return $true }

    $wss = tfs-get-workspaces $GLOBAL:Sf.Config.tfsServerName | Where-Object { IsDuplicate $_ }
    if ($wss) { return $true }

    Import-Module WebAdministration
    $sites = Get-Item "IIS:\Sites"
    if ($sites -and $sites.Children) {
        $names = $sites.Children.Keys | Where-Object { IsDuplicate $_ }
        if ($names) { return $true }
    }
    $pools = Get-Item "IIS:\AppPools"
    if ($pools -and $pools.Children) {
        $names = $pools.Children.Keys | Where-Object { IsDuplicate $_ }
        if ($names) { return $true }
    }
    
    $dbs = $tokoAdmin.sql.GetDbs() | Where-Object { IsDuplicate $_.name }
    if ($dbs) { return $true }

    return $false;
}

function GenerateId {
    $i = 0;
    while ($true) {
        $name = "$($GLOBAL:Sf.Config.idPrefix)$i"
        $IsDuplicate = (GetIsIdDuplicate $name)
        if (-not $IsDuplicate) {
            break;
        }
        
        $i++
    }

    if ([string]::IsNullOrEmpty($name) -or (-not (ValidateNameSyntax $name))) {
        throw "Invalid id $name"
    }
    
    return $name
}

function SetCurrentProject {
    Param(
        [SfProject]$newContext
    )
        
    if ($null -ne $newContext) {
        InitializeProject $newContext
        ValidateProject $newContext        
    } 

    $Script:globalContext = $newContext
    SetConsoleTitle -newContext $newContext
    Set-Prompt -project $newContext
}

function SetConsoleTitle {
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

function GenerateSolutionFriendlyName {
    Param(
        [SfProject]$context
    )
    
    if (-not ($context)) {
        $context = Get-CurrentProject
    }

    $solutionName = "$($context.displayName)($($context.id)).sln"
    
    return $solutionName
}

function ValidateNameSyntax ($name) {
    return $name -match "^[A-Za-z]\w+$" -and $name.Length -lt 75
}

function CreateWorkspace ($context, $branch) {
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
        SaveSelectedProject $context
    }
    catch {
        throw "Could not get latest workapce changes. $_"
    }
}

function InitializeProject {
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
        throw "Cannot initialize a project with no display name or id."    
    }

    $errorMessgePrefix = "ERROR Working with project $($project.displayName) in $($project.webAppPath) and id $($project.id)."

    if (!(Test-Path $project.webAppPath)) {
        throw "$errorMessgePrefix $($project.webAppPath) does not exist."
    }


    $isSolution = Test-Path "$($project.webAppPath)\..\Telerik.Sitefinity.sln"
    if ($isSolution) {
        $project.solutionPath = (Get-Item "$($project.webAppPath)\..\").Target
        CreateUserFriendlySlnName $project
    }
    
    $branch = tfs-get-branchPath -path $project.webAppPath
    if ($branch) {
        $project.branch = $branch
        UpdateLastGetLatest -context $project
    }
    else {
        Write-Warning "$errorMessgePrefix Could not detect source control branch, TFS related functionaliuty for the project will not work."
    }
    
    $siteName = iis-find-site -physicalPath $project.webAppPath
    if ($siteName) {
        $project.websiteName = $siteName
    }
    else {
        Write-Warning "$errorMessgePrefix Could not detect website for the current project."
    }

    SaveSelectedProject -context $project
    $project.isInitialized = $true

    $WarningPreference = $oldWarningPreference
}

function CreateProjectFilesFromSource {
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
        $project.solutionPath = $projectDirectory
        $newContext.webAppPath = "$projectDirectory\SitefinityWebApp";
        CreateWorkspace $project $sourcePath
    }
    else {
        if (!(Test-Path -Path $sourcePath) -or !(Test-Path -path "$sourcePath\SitefinityWebApp.zip")) {
            throw "Source path does not exist $sourcePath, unreachable or no SitefinityWebApp.zip archive found in it."
        }

        $project.webAppPath = $projectDirectory
        expand-archive -path "$sourcePath\SitefinityWebApp.zip" -destinationpath $project.webAppPath
    }
}

function Get-AzureDevOpsTitleAndLink {
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
            $name = Get-ValidTitle $name

            $description = "https://prgs-sitefinity.visualstudio.com/sitefinity/_workitems/edit/$itemId"
        }
    }

    return @{ name = $name; link = $description }
}

function Get-ValidTitle {
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
        } elseif ($title[$i] -eq ' ') {
            $resultTitle = "${resultTitle}_"
        }
    }

    if ($resultTitle.Length -ge 51) {
        $resultTitle = $resultTitle.Remove(50);
    }
    
    return $resultTitle;
}
