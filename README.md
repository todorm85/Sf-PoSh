# Tool for local sitefinity instance management

Each folder in this repo is a powershell module. Currently only SfDevTool module is stable. This is the core module required by the rest to run.

## Description
This tool allows easy sitefinity web apps setup and teardown on a local machine. It automates the process of creating a workspace in tfs, getting the latest changes, creating a website and hosting the app there as well as complete rollback. It also provides automation of resetting, rebuilding, cleaning of the web app and more.

## Prerequisites (IMPORTANT)
- Powershell 4.0 or later

## SetUp
1. Copy the modules directories to your powershell user modules directory - ex. C:\Users\{YourWinUserName}}\Documents\WindowsPowerShell\modules
2. Setup environment constants. Open for edit .\SfDevTool\EnvConstants.ps1. Please, enter your environment specific paths there in order for all functionality to work correctly.
2. Make sure the modules are loaded by executing
Get-Module -ListAvailable
3. To get all function for a module type:
Get-Command -Module {ModuleName} | Get-Help | Format-List -Property Name, Synopsis
4. To get more detailed help for function type:
Get-Help {Function name} -full