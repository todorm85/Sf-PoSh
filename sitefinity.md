# Tool for local sitefinity instance management

## Description
This tool allows easy sitefinity web apps setup and teardown on a local machine. It automates the process of creating a workspace in tfs, getting the latest changes, creating a website and hosting the app there as well as complete rollback. It also provides automation of resetting, rebuilding, cleaning of the web app and more.

## Prerequisites (IMPORTANT)
- Powershell 4.0 or later
- Open for edit sitefinity.ps1 and in the beginning of the file there is a section 'Environment Constants'. Please, enter your environment specific paths there in order for all functionality to work correctly.

## Usage
Navigate to the directory where sitefinity.ps1 is located. Open a powershell instance with admin rights there. 'Dot source' the script by entering: `. ./sitefinity.ps1` (Note there are two dots, delimted by spacial character). Start typing `sf-` then press tab repeatedly to cycle through available functions. You can narrow the filter by further typing the desired function name - e.x. `sf-show`.

## Functions
Optional params given in [].

### Sitefinity instances management

`sf-create-sitefinity name [branch]`

Creates a new instance of sitefinity and adds it to sitefinities that are managed by the script. Default conventions for website, database and folder names are used. These can be changed. If branch not specified the hardcoded in sitefinity.ps1 script will be used. If name is not specified user will be prompted. The script uses sf-data.xml file to persist sitefinity instances that are managed by it. You can also add entries there for manually created ones:
<sitefinity name="" solutionPath="" workspaceName="" dbName="" websiteName="" port="" appPool="" />
When doing so don't add workspace name if you don't use it exclusively for that sitefinity instance. It will be deleted if you use 'sf-delte-sitefinity'
The conventions used can be changed in the script in function '_sfData-apply-contextConventions'

Params:
- name: used for naming the created instance that will be managed by the script. Also used in conventions when creating local folder, website, workspace etc.
- branch (optional): specifies the sitefinity instance's branch in tfs

Example: 'sf-create-sitefinity "TestSitefinity" "$/CMS/Sitefinity 4.0/OfficialReleases/DBP"'
Will create the following:
- new workspace named TestSitefinity with local mapping of the DBP branch to d:\TestSitefinity
- new website called TestSitefinity with app path to d:\TestSitefinity\SitefinityWebApp and the first avbailable port starting from 1111. Default app pool is used by default.
- the web app will be initiated with startupConfig and a database named TestSitefinity will be created. The app will be added default admin user called 'admin' with pass 'admin@2'

`sf-show-sitefinities`

Lists all sitefinities managed by the script (located in sf-data.xml)

`sf-delete-sitefinity`

Deletes the currently selected sitefinity instance. Removes all including the workspace, website, database, local directories.

`sf-select-sitefinity`

Lists and allows to select the sitefinity that will be managed.

`sf-show-sitefinityDetails`

Displays details about the currently selected sitefinity instance.

### Web app management

All functions here operate in the context of the selected sitefinity instance

`sf-open-webApp`
Opens the web app in web browser

`sf-reset-webApp [-start -build -rebuild -configRestrictionSafe]`
Resets the web app by deleting the database, all config and log files and reinitializes the instance with new startup.config.
Switches:
- start: initiates the web app after restarting. If this switch is omitted the web app will not be initiated, only startup.config file will be created in Configs directory. Initialization will begin the first time the web app is opened in the browser.
- build: will build the solution.
- rebuild: will rebuild the solution. It uses an internal function rebuild that does a 'true' rebuild - manually deletes all packages, all bins and obj folders and then builds the solution.
- configRestrictionSafe: takes care to remove readOnlyConfigRestriction level if it is turned on, before reinitializing the web app and then turns it back on

`sf-add-precompiledTemplates`
Adds precompiled templates

`sf-remove-precompiledTemplates`
Removes any added precopiled templates

### Solution management

All functions here operate in the context of the selected sitefinity instance

`sf-get-latest`
Gets the latest changes from tfs

`sf-open-solution`
Opens the solution (telerik.sitefinity.sln) with default VS instance. Specified in constants in the script.

`sf-build-solution`

`sf-rebuild-solution`
Does a 'true' rebuild. Manually, deletes all bins and obj folders, packages and then builds solution.

### Configs management

`sf-set-storageMode [storageMode restrictionLevel]`
Sets the storage mode. If no params are specified user is prompted. It is easier to use it without passing params so you don`t have to type them, but simply choose from available.
Params:
- storageMode: the config storage mode to be used by the system (FileSystem, Database, Auto).
- restrictionLevel: applied only for auto storage mode (Default or ReadOnlyConfigFile)

`sf-get-storageMode`
Displays the current storage mode settings used

`sf-load-configFromDbToFile configName [filePath]`
Reads the config file from the database and saves it prettified to the filePath specified.
Params:
- configName: the name of the config file
- filePath (optional): the path used to save the read config. If not specified Desktop\dbConfig.xml is used.

`sf-clear-configFromDb configName`
Removes the specified config from the database if it exists.

# DBP management
Settings here depend on the scripts in \Builds\DBPModuleSetup\ in the tfs branch. Check if they exist.

`sf-install-dbp accountId`
Makes all the necessary changes to the web app so it can run with DBP module enabled locally.
Params:
- accountId: the dbp organization account id for which to setup the locally run sitefinity instance

`sf-uninstall-dbp`
Removes all the changes to the web app related to enabling the DBP module

# IIS management

`sf-reset-appPool [-start]`
Resets the app pool.
Switches:
- start: reintiialize the web app after restart

`sf-change-appPool`
Changes the app pool used by the selected sitefinity instance. User is prompted to select the new app pool from all available in IIS.

# Misc functions

`sf-clear-nugetCache`
Clears local machine nuget cache

`sf-open-appData`
Opens the App_Data/Sitefinity folder