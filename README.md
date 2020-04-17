# Sitefinty PowerShell Module for Sitefinity core developers

## Description

Manage, provision and automate Sitefinity instances on local machine.

## Installation

To install see: [PowerShell Gallery](https://www.powershellgallery.com/packages/sf-dev/). If problems see [How-To-Update-Powershell get](https://docs.microsoft.com/en-us/powershell/gallery/installing-psget)

## Requirements

- Powershell 5.1 64bit
- VS 2017 (or other, but needs configuration)
- First run of internet explorer to have completed (this is required for the WebClient in .NET)
- Enabled IIS server feature, which should add the WebAdministration powershell module

## Links

[Release Notes](./sf-dev/sf-dev.psd1)

## Quickstart
In powershell console window type:
``` PowerShell
Import-Module sf-dev
sf-config-open # opens the configuration file with its default settings and paths (set for VS2017 tools) after editing you must restart the powershell session
sf- #then press (ctrl + space), which should list all commands
sf-proj #then ctrl+space, would list all related to module`s projects commands etc.
sf-project-new -displayName test -sourcePath "any path to sitefinity web app zip or tfs branch" # this creates a new project, in case of tfs branch a separate workspace. It is automatically selected for the current session. All commands that are executed in the powershell session are modifying the currently selected project - it should be displayed on the prompt and on the console status bar.
sf-project-select # to select a different project previously created etc.
sf-project-getCurrent # returns the currently selected project object
sf-project-set # sets the project object passed to the command as the current 

sf # function that is a facade and container for most useful operations regarding resetting 
# and reinitializing sitefinity, getting latest changes etc. all operations are passed as
# switches ex:
sf -getLatestChanges -buildSolution
```
