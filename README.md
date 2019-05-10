# SF-DEV PowerShell Module

## Description

Manage Sitefinity instances on local machine.

## QuickStart

- To install see: [PowerShell Gallery](https://www.powershellgallery.com/packages/sf-dev/). If problems see [How-To-Update-Powershell get](https://docs.microsoft.com/en-us/powershell/gallery/installing-psget)

- Run powershell as Administrator

DO NOT USE ~~Import-Module~~, USE `Using module` instead
```powershell
Using module sf-dev
```

_After first run you might get asked to setup paths to external tools. Config is at `%userprofile%\Documents\sf-dev\config.ps1.`. After modification restart powershell session_

- Start typing
```powershell
$sf.
```
Assuming you are using standard Windows PowerShell console, press __LEFTCTRL+SPACE__ to see a list of available categories of operations. Or start typing and press __TAB__ for autocomplete.

First, you need to create a project.
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

## Requirements

- Powershell 5.1
- MSBuild.exe and TF.exe (Come with Visual Studio 2015 or later)
- SQL Server PowerShell Module (SQLPS) (Comes with SQL Server Management Studio)
- First run of internet explorer to have completed (this is required for the WebClient in .NET)
- WebAdministration module (this should already be installed if IIS is enabled)

## Links

[Docs](./docs.md)

[Release Notes](./sf-dev/sf-dev.psd1)