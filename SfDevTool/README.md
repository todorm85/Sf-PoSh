# Sitefinity tools

## Description
This powershell module provides tooling for various sitefinity instance administration tasks.

## Prerequisites
- Powershell 5.0 or later

## Installation
- Copy contents
- Setup environment constants. Open for edit EnvConstants.ps1. Please, enter your environment specific paths there in order for all functionality to work correctly.

## Usage
Start typing `sf-` then press tab repeatedly to cycle through available functions. You can narrow the filter by further typing the desired function name - e.x. `sf-show`.

TODO: Explain how to get help with standard ps commands.




// TODO: Insert in functions
## Functions
Mandatory params given in ().
Optional params given in [].

### Sitefinity instances management

`sf-create-sitefinity (name) [branch]`

Creates a new instance of sitefinity and adds it to sitefinities that are managed by the script. Default conventions for website, database and folder names and locations are used. These can be changed. If branch not specified the hardcoded in sitefinity.ps1 script will be used. The script uses sf-data.xml file to persist information about sitefinity instances that are managed by it. You can also add entries there for manually created ones:
<sitefinity name="" solutionPath="" workspaceName="" dbName="" websiteName="" port="" appPool="" />
When doing so don't add workspace name if you don't use it exclusively for that sitefinity instance. It will be deleted if you use 'sf-delte-sitefinity'
The conventions used can be changed in the script in function '_sfData-apply-contextConventions'

Params:
- name: used for naming the created instance that will be managed by the script.
- branch (optional): specifies the sitefinity instance's branch in tfs

Example: 'sf-create-sitefinity "TestSitefinity" "$/CMS/Sitefinity 4.0/OfficialReleases/DBP"'
Will create the following:
- new workspace named TestSitefinity with local mapping of target TFS branch to d:\workspaces\instance{#theNumberOfCurrentSitefinity}\
- new website called instance{#theNumberOfCurrentSitefinity} with app path to d:\workspaces\instance{#theNumberOfCurrentSitefinity}\SitefinityWebApp\ and the first avbailable port starting from 1111. DefaultAppPool is used by default.
- the web app will be initiated with startupConfig with a database named "instance{#theNumberOfCurrentSitefinity}" and default admin user called 'admin' with pass 'admin@2'

`sf-show-sitefinities`

Lists all sitefinities managed by the script (located in sf-data.xml)

`sf-delete-sitefinity`

Deletes the currently selected sitefinity instance. Removes all including the workspace, website, database, local directories.

`sf-select-sitefinity`

Lists and allows to select the sitefinity that will be managed.

`sf-show-sitefinityDetails`

Displays details about the currently selected sitefinity instance.

`sf-rename-sitefinity (name)`

Renames the current sitefinity. If no name is specified sitefinity is renamed to its default name -> instance{#theNumberOfCurrentSitefinity}.

### Web app management

All functions here operate in the context of the selected sitefinity

`sf-reset-sitefinityWebApp [-start -build -rebuild -configRestrictionSafe]`
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

`sf-show-pendingChanges`
Shows pending changes for current sitefinity

`sf-open-solution`
Opens the solution (telerik.sitefinity.sln)

`sf-build-solution`

`sf-rebuild-solution`
Does a 'true' rebuild. Manually, deletes all bins and obj folders, packages and then builds solution.

### Configs management

`sf-set-storageMode`
Sets the config storage mode.

`sf-get-storageMode`
Displays the current config storage mode settings used

`sf-load-configFromDbToFile (configName) [filePath]`
Reads the config file from the database and saves it prettified to the filePath specified.
Params:
- configName: the name of the config file without extension
- filePath (optional): the path used to save the extracted config. If not specified Desktop\dbConfig.xml is used.

`sf-clear-configFromDb configName`
Clears the specified config in the database if it exists.

`sf-insert-configContentInDb (configName) [filePath]`
Inserts the config to db.
Params:
- configName: the name of the config file without extension
- filePath (optional): the path used to save the extracted config. If not specified Desktop\dbImport.xml is used.

`sf-insert-configContentInDb (configName) [filePath]`
Inserts the contents of file with given path to config with name configName in sf_xml_configs table 

# IIS management

`sf-browse-webSite`
Opens the web app in the browser

`sf-reset-webSiteApp [-start]`
Resets the web app by writing a dummy file to bin folder then deletes it. Useful when running many apps in one app pool, but only current web app is needed to be reset.
Switches:
- start: reintiialize the web app after restart

`sf-reset-appPool [-start]`
Resets the app pool.
Switches:
- start: reintiialize the web app after restart

`sf-change-appPool`
Changes the app pool used by the selected sitefinity instance. User is prompted to select the new app pool from all available in IIS.

# Misc functions

`sf-clear-nugetCache`
Clears local machine nuget cache

`sf-explore-appData`
Opens the App_Data/Sitefinity folder