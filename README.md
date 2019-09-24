# SF-DEV PowerShell Module

## Description

Manage Sitefinity instances on local machine.

## Installation

To install see: [PowerShell Gallery](https://www.powershellgallery.com/packages/sf-dev/). If problems see [How-To-Update-Powershell get](https://docs.microsoft.com/en-us/powershell/gallery/installing-psget)

## QuickStart

## Requirements

- Powershell 5.1
- MSBuild.exe and TF.exe (Come with Visual Studio 2015 or later)
- SQL Server PowerShell Module (SQLPS) (Comes with SQL Server Management Studio)
- First run of internet explorer to have completed (this is required for the WebClient in .NET)
- WebAdministration module (this should already be installed if IIS is enabled)

## Links

[Docs](./docs.md)

[Release Notes](./sf-dev/sf-dev.psd1)

## Tips & Tricks

- iterate through all projects and perform operations
    ```PowerShell
    # this function comes from the module and can be used to iterate and perform operations on each project managed by the module
    start-allProjectsBatch {
        Param([SfProject]$project)
        if ($project.displayName -eq 'myProject' -or $project.branch.StartsWith("Fixes_")) {
            # do stuff with $project
        }
    }
    ```

    
