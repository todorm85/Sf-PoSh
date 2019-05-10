# Sf-Dev PowerShell Module Auto-Generated Documentation
## Project operations

-  Select ()

    Prompts the user to select a project to work with from previously created or imported.

-  Create ()

    Use to create new projects. The user will be prompted to select branch from configured ones and name for the project

-  Create ([string]$name, [string]$branchPath)

    Use to create new projects. $branchPath - the TFS branch path to the source

-  Import ([string]$name, [string]$path)

    Use to import existing sitefinity projects to be managed by the tool. $name - the name of the imported project. $path - the directory of the Sitefinity web app

-  Import ([string]$name, [string]$path, [bool]$cloneDb)

    Use to import existing sitefinity projects to be managed by the tool. $name - the name of the imported project. $path - the directory of the Sitefinity web app. $cloneDb - whether to use the same database or clone

-  Clone()

    Use to clone the current project. Will create a copy of everything - site, database and map into a new workspace

-  Delete()

    Delete the current project

-  DeleteMany()

    Batch delete projects

-  Rename([string]$newName)

    Rename the current project

-  Details()

    Display details about the current project

## IIS operations

-  SetupSubApp($subAppName)

    Setups the current project as a sub application in IIS

-  RemoveSubApp()

    Reverts the sub application mode in IIS of the current project if it was enabled

-  ResetApplicationPool ()

    Resets the website ApplicationPool

-  ResetApplciationThreads()

    Resets just the threads of the website application but leaves the ApplicationPool intact, useful if you need to restart hte app domain bu leave the debugger attached for startup debugging

-  BrowseWebsite ()

    Opens the configured web browser with the url of the project

## Web Application operations

-  ResetApp ()

    Resets and reinitializes the web application. This will delete database and restore AppData folder to original state, before initiating a Sitefinity startup

-  SaveDbAndConfigs([string]$stateName)

    Saves the current web application AppData and Database state for later restore. Useful when debugging tests that change the state of the system. Ex. switch from single to multilingual or delete some content items etc...

-  SaveDbAndConfigs()

    Saves the current web application AppData and Database state for later restore. Useful when debugging tests that change the state of the system. Ex. switch from single to multilingual or delete some content items etc...

-  RestoreDbAndConfigs([string]$stateName)

    Restores previously saved database and AppData folder

-  RestoreDbAndConfigs()

    Restores previously saved database and AppData folder

## Solution operations

-  Build ()

    Builds the solution with 3 retries. Also disables stylecop check for faster build. Uses msbuild configured for multi threaded building.

-  Build ([int]$retryCount)

    Builds the solution with given retries count. Also disables stylecop check for faster build. Uses msbuild configured for multi threaded building.

-  ReBuild ([int]$retryCount)

    Performs a hard clean of the project before building. Deletes all bin and obj folders from all projects

-  CleanPackages ()

    Cleans downloaded packages for solution

-  Clean ()

    Performs a hard delete of all bins and objs

-  Open ()

    Opens the solution in the configured editor of the tool config
