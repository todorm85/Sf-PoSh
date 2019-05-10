# Sf-Dev PowerShell Module Auto-Generated Documentation
## Project operations

-  Select ()

    _Prompts the user to select a project to work with from previously created or imported._

-  Create ()

    _Use to create new projects. The user will be prompted to select branch from configured ones and name for the project_

-  Create ([string]$name, [string]$branchPath)

    _Use to create new projects. $branchPath - the TFS branch path to the source_

-  Import ([string]$name, [string]$path)

    _Use to import existing sitefinity projects to be managed by the tool. $name - the name of the imported project. $path - the directory of the Sitefinity web app_

-  Import ([string]$name, [string]$path, [bool]$cloneDb)

    _Use to import existing sitefinity projects to be managed by the tool. $name - the name of the imported project. $path - the directory of the Sitefinity web app. $cloneDb - whether to use the same database or clone_

-  Clone()

    _Use to clone the current project. Will create a copy of everything - site, database and map into a new workspace_

-  Delete()

    _Delete the current project_

-  DeleteMany()

    _Batch delete projects_

-  Rename([string]$newName)

    _Rename the current project_

-  Details()

    _Display details about the current project_

## IIS operations

-  SetupSubApp($subAppName)

    _Setups the current project as a sub application in IIS_

-  RemoveSubApp()

    _Reverts the sub application mode in IIS of the current project if it was enabled_

-  ResetApplicationPool ()

    _Resets the website ApplicationPool_

-  ResetApplciationThreads()

    _Resets just the threads of the website application but leaves the ApplicationPool intact, useful if you need to restart hte app domain bu leave the debugger attached for startup debugging_

-  BrowseWebsite ()

    _Opens the configured web browser with the url of the project_

## Web Application operations

-  ResetApp ()

    _Resets and reinitializes the web application. This will delete database and restore AppData folder to original state, before initiating a Sitefinity startup_

-  SaveDbAndConfigs([string]$stateName)

    _Saves the current web application AppData and Database state for later restore. Useful when debugging tests that change the state of the system. Ex. switch from single to multilingual or delete some content items etc..._

-  SaveDbAndConfigs()

    _Saves the current web application AppData and Database state for later restore. Useful when debugging tests that change the state of the system. Ex. switch from single to multilingual or delete some content items etc..._

-  RestoreDbAndConfigs([string]$stateName)

    _Restores previously saved database and AppData folder_

-  RestoreDbAndConfigs()

    _Restores previously saved database and AppData folder_

## Solution operations

-  Build ()

    _Builds the solution with 3 retries. Also disables stylecop check for faster build. Uses msbuild configured for multi threaded building._

-  Build ([int]$retryCount)

    _Builds the solution with given retries count. Also disables stylecop check for faster build. Uses msbuild configured for multi threaded building._

-  ReBuild ([int]$retryCount)

    _Performs a hard clean of the project before building. Deletes all bin and obj folders from all projects_

-  CleanPackages ()

    _Cleans downloaded packages for solution_

-  Clean ()

    _Performs a hard delete of all bins and objs_

-  Open ()

    _Opens the solution in the configured editor of the tool config_
