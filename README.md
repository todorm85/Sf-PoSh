# Tool for local sitefinity instance management

## Description

Manage Sitefinity instances on local machine.

## Prerequisites

- Powershell 5.1
- MSBuild.exe and TF.exe (Come with Visual Studio 2015 or later)
- SQL Server PowerShell Module (SQLPS) (Comes with SQL Server Management Studio)
- First run of internet explorer to have completed (this is required for the WebClient in .NET)
- WebAdministration module (this should already be installed if IIS is enabled)

## QuickStart

- To install see: [PowerShell Gallery](https://www.powershellgallery.com/packages/sf-dev/). If problems see [How-To-Update-Powershell get](https://docs.microsoft.com/en-us/powershell/gallery/installing-psget)

- Run powershell as Administrator

DO NOT USE ~~Import-Module~~, USE `Using module` instead
```powershell
Using module sf-dev
```

_After first run you might get asked to setup paths to external tools. You should be fine if you have VS2017 Pro, SQL management tools and IIS enabled. Enter your env specific paths in your user profile dir `.\Documents\sf-dev\config.ps1.`. After that close and re-open a new powershell session and load the module again_

- Start typing
```powershell
$sf.
```
Assuming you are using standard Windows PowerShell console, press __LEFTCTRL+SPACE__ to see a list of available categories of operations
select one or start typing any of it and press __TAB__ for autocomplete.

First, you need to create a project
```powershell
$sf.project.Create()
```
Choose branch to map from and the name of your Sitefinity instance.

A project is a Sitefinity instance that is managed by the tool. To select from all created and imported projects use
```powershell
$sf.project.Select()
```

To build the currently selected project use:
```powershell
$sf.solution.Build()
```

To see other available commands for solution type
```powershell
$sf.solution.
```
then press __LEFTCTRL+SPACE__
