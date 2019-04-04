# Tool for local sitefinity instance management

To install in PowerShell 5.1 console type:
``` PowerShell
Install-Module -Name sf-dev
```
If you have trouble with outdated nuget and PowerShell-get module versions see [How-To-Update-Powershell get](https://docs.microsoft.com/en-us/powershell/gallery/installing-psget)

## Description

This tool allows easy sitefinity web apps provisioning and orchestration on a local development environment. It automates the process of creating a workspace in tfs, getting the latest changes, creating a website and hosting the app there as well as complete rollback. It also provides automation of resetting, rebuilding, cleaning of the web app and more.

## Prerequisites

- Powershell 5.1 or later
- Visual Studio 2017
- SQL Server PowerShell Module (SQLPS) (This should be preinstalled with SQL Server Management Studio unless it was deselected during setup)
- First run of internet explorer to have completed (this is required for the WebClient in .NET)
- WebAdministration module (this should already be installed if IIS feature is enabled in windows)

## QuickStart

ALWAYS RUN THE MODULE IN AN ELEVATED POWERSHELL INSTANCE

### Setup and import

- Run powershell as Administrator

- Use this powershell command
```powershell
Import-Module sf-dev
```

_On first run you might get asked to setup paths to external tools. Enter your env specific paths in your user profile dir `.\Documents\sf-dev\config.ps1.`. After that re-import the module specifying the `-Force` switch or close and open a new powershell window_

### Basic commands

- Create a new isntance locally called testInstance from a specific branch, build it, initiate the web app with default user and pass as in config.ps1 and add precompiled tempaltes
```powershell
sf-new-project -displayName test -buildSolution -startWebApp -precompile -predefinedBranch '$/CMS/Sitefinity 4.0/Code Base'
```
The webapp will be tracked in a separate private workspace in TFS with the same name as the identifier. Projects in the tool are identified by following convention: instance_0, instance_1 etc...

- To get more info about the created sitefinity instance type:
```powershell
sf-show-currentProject -detail
```

- To browse to the newly created app type
```powershell
sf-browse-webSite
```

- To reset the app

```powershell
sf-reset-app
```
This will simply put the app in default state as if it were never initialized, if you browse to it after that you will have to go through startup wizzard

#### switches:

-start
This will reset the app and reinitialize it with default user (admin@test.test), password is same as user.
There are several more switches that can be issued with the command, feel free to explore.

```powershell
sf-reset-app -start -rebuild
```
This will also make a 'true' rebuild - manuially delete all in bins and objs of all projects, clean nuget cache, delete downloaded nuget packages, then build the solution or sitefinity app

```powershell
sf-reset-app -start -build
```
This will also build the app besides resetting it.

- To delete the current selected sitefinity
```powershell
sf-delete-project
```
Will remove everything associated with current selected sitefinity instance (db/iis site/ local directory/tfs workspace)

- To select a different sitefinity that is managed by the tool type:
```powershell
sf-select-project
```
- To save the app state for faster restoration later (Database and config files)
```powershell
sf-save-appState
```
- To restore previous app state (Database and config files)
```powershell
sf-restore-appState
```
- To clone the instance (Sitefinity + database) to a new instance, hosted on new website.
```powershell
sf-clone-project
```

### Import existing sitefinity web app to manage

To do that you need to import it.
```powershell
sf-import-project [name] [path]
```
Name is the identifier of the app in the tool.
Path either the path to folder containing either the Telerik.Sitefinity.sln or SitefinityWebApp.csproj files.
Note that if the app is not under TFS source control all related tfs commands will throw and won`t make any changes. You might expirience some error messages related to tfs that you cna safely ignore.

WARNING: If your imported sitefinity is a copy of another that is initialized with a databse, after you import the cloned one if you reset it it will also reset(delete) the same database. If that is undesired change the associated database name in DataConfig and then reset the app (sf-reset-app -start). If the database does not exist it will be created upon reset.

## Other useful commands

```powershell
sf-show-currentProject -detail
```
Shows the current selected sitefinity instance for that powershell window.

```powershell
sf-open-solution
```
Opens Telerik.Sitefinity.sln if there is one or the SitefinityWebApp.csproj

```powershell
sf-add-precompiledTemplates
```
Adds precompiled templates to the app, use the -revert switch to remove them.

```powershell
sf-reset-thread
```
Resets just the app threads not the entire pool process. Useful when multiple sitefinities use same app pool instance. Other apps don`t get reset.

```powershell
sf-setup-asSubApp
```
Sets up the current app in sub application mode in iis.

```powershell
sf-remove-subApp
```
Undo sub application mode in iis.

```powershell
sf-get-poolId
```
Useful the get the process id of the current app pool the web app is running on.

### To get more help
1. To get all function for a module type:
```powershell
Get-Command -Module sf-dev
```
2. To get more detailed help for function type:
```powershell
Get-Help {Function name} -full
```
