# Tool for local sitefinity instance management

## Description
This powershell module provides tooling for various sitefinity instance administration tasks.

## Prerequisites (IMPORTANT)
- Powershell 5.0 or later

## SetUp
1. Copy the module directory to your powershell user modules directory - ex. C:\Users\{YourWinUserName}}\Documents\WindowsPowerShell\modules. If it does not exist create it.
2. Setup environment constants. Open for edit .\SfDevTool\EnvConstants.ps1. Please, enter your environment specific paths there in order for all functionality to work correctly.
2. Make sure the modules are loaded by executing
Get-Module -ListAvailable
3. To get all function for a module type:
Get-Command -Module {ModuleName} | Get-Help | Format-List -Property Name, Synopsis
4. To get more detailed help for function type:
Get-Help {Function name} -full

## Usage
First you need to import an existing sitefinity project or provision one from TFS. (use 'sf-import-sitefinity' or 'sf-provision-sitefinity'). Start typing `sf-` then press tab repeatedly to cycle through available functions. You can narrow the filter by further typing the desired function name - e.x. `sf-show`. You can import and provision as many as you like. Each time a powershell session is opened and the module is loaded you need to select the sitefinity with which you would be working in that powershell window.

TODO: add more description