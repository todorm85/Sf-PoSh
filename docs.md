# Sf-Dev PowerShell Module Auto-Generated Documentation
## Project operations

- __Select ()__

    _Prompts the user to select a project to work with from previously created or imported._

- __Create ()__

    _Use to create new projects. The user will be prompted to select branch from configured ones and name for the project_

- __Create ([string]$name, [string]$branchPath)__

    _Use to create new projects. $branchPath - the TFS branch path to the source_

- __Import ([string]$name, [string]$path)__

    _Use to import existing sitefinity projects to be managed by the tool. $name - the name of the imported project. $path - the directory of the Sitefinity web app_

- __Import ([string]$name, [string]$path, [bool]$cloneDb)__

    _Use to import existing sitefinity projects to be managed by the tool. $name - the name of the imported project. $path - the directory of the Sitefinity web app. $cloneDb - whether to use the same database or clone_

- __Clone()__

    _Use to clone the current project. Will create a copy of everything - site, database and map into a new workspace_

- __Delete()__

    _Delete the current project_

- __DeleteMany()__

    _Batch delete projects_

- __Rename([string]$newName)__

    _Rename the current project_

- __Details()__

    _Display details about the current project_

## IIS operations

- __SetupSubApp($subAppName)__

    _Setups the current project as a sub application in IIS_

- __RemoveSubApp()__

    _Reverts the sub application mode in IIS of the current project if it was enabled_

- __ResetApplicationPool ()__

    _Resets the website ApplicationPool_

- __ResetApplciationThreads()__

    _Resets just the threads of the website application but leaves the ApplicationPool intact, useful if you need to restart hte app domain bu leave the debugger attached for startup debugging_

- __BrowseWebsite ()__

    _Opens the configured web browser with the url of the project_

## Web Application operations

- __ResetApp ()__

    _Resets and reinitializes the web application. This will delete database and restore AppData folder to original state, before initiating a Sitefinity startup_

- __SaveDbAndConfigs([string]$stateName)__

    _Saves the current web application AppData and Database state for later restore. Useful when debugging tests that change the state of the system. Ex. switch from single to multilingual or delete some content items etc..._

- __SaveDbAndConfigs()__

    _Saves the current web application AppData and Database state for later restore. Useful when debugging tests that change the state of the system. Ex. switch from single to multilingual or delete some content items etc..._

- __RestoreDbAndConfigs([string]$stateName)__

    _Restores previously saved database and AppData folder_

- __RestoreDbAndConfigs()__

    _Restores previously saved database and AppData folder_

## Solution operations

- __Build ()__

    _Builds the solution with 3 retries. Also disables stylecop check for faster build. Uses msbuild configured for multi threaded building._

- __Build ([int]$retryCount)__

    _Builds the solution with given retries count. Also disables stylecop check for faster build. Uses msbuild configured for multi threaded building._

- __ReBuild ([int]$retryCount)__

    _Performs a hard clean of the project before building. Deletes all bin and obj folders from all projects_

- __CleanPackages ()__

    _Cleans downloaded packages for solution_

- __Clean ()__

    _Performs a hard delete of all bins and objs_

- __Open ()__

    _Opens the solution in the configured editor of the tool config_
