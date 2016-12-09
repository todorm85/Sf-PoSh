# Tool for local sitefinity instance management

## Description
This tool allows easy sitefinity web apps setup and teardown on a local machine. It automates the process of creating a workspace in tfs, getting the latest changes, creating a website and hosting the app there as well as complete rollback. It also provides automation of resetting, rebuilding, cleaning of the web app and more.

## Prerequisites (IMPORTANT)
- Powershell 4.0 or later
- Setup environment constants. Open for edit EnvConstants.ps1 and section 'Environment Constants'. Please, enter your environment specific paths there in order for all functionality to work correctly.

## SetUp
1. Copy the modules directories to your powershell user modules directory - ex. C:\Users\{YourWinUserName}}\Documents\WindowsPowerShell\modules
2. Make sure the modules are loaded by executing
Get-Module -ListAvailable
3. To get all function for a module type:
Get-Command -Module {ModuleName}
4. To get help for function type:
Get-Help {function name} -full