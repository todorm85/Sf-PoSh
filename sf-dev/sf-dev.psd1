@{
    RootModule        = '.\sf-dev.psm1'
    GUID              = '570fb657-4d88-4883-8b39-2dae4db1280c'
    Author            = 'Todor Mitskovski'
    Copyright         = '(c) 2019 Todor Mitskovski. All rights reserved.'
    Description       = 'Manage Sitefinity instances on local machine. Docs: https://github.com/todorm85/sitefinity-dev-orchestration/blob/master/README.md'
    PowerShellVersion = '5.1'
    CLRVersion        = '4.0'
    FunctionsToExport = 'Get-AllProjects', 'Start-AllProjectsBatch', 'Set-Description', 'New-Project', 'Copy-Project', 'Import-Project', 'Remove-ManyProjects', 'Remove-Project', 'Rename-Project', 'Reset-Project', 'Get-CurrentProject', 'Open-Description', 'Get-AzureDevOpsTitleAndLink', 'Get-ValidTitle', 'Add-TagToProject', 'Remove-TagFromProject', 'Remove-AllTagsFromProject', 'Get-AllTagsForProject', 'Set-DefaultTagFilter', 'Get-DefaultTagFilter', 'Update-AllProjectsTfsInfo', 'Clear-AllProjectsLeftovers', 'Goto', 'Select-Project', 'Show-CurrentProject', 'Show-Projects', 'Start-SolutionBuild', 'Start-SolutionReBuild', 'Start-SolutionClean', 'Clear-Packages', 'Open-Solution', 'Start-WebAppProjBuild', ' Unlock-AllProjectFiles', 'Switch-StyleCop', 'Undo-PendingChanges', 'Show-PendingChanges', 'Get-HasPendingChanges', 'Get-LatestChanges', 'Reset-Thread', 'Reset-Pool', 'Stop-Pool', 'Switch-AppPool', 'Get-PoolId', 'Set-SubApp', 'Remove-SubApp', 'Rename-Website', 'Open-WebSite', 'New-Website', 'Set-StorageMode', 'Get-StorageMode', 'Get-ConfigContentFromDb', 'Clear-ConfigContentInDb', 'Set-ConfigContentInDb', 'Get-AppDbName', 'Set-AppDbName', 'Reset-App', 'Add-PrecompiledTemplates', 'Save-AppState', 'Restore-AppState', 'Remove-AppState', 'Remove-AllAppStates'
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = '*'
    ModuleVersion     = '3.0.0'
    RequiredModules   = @(
        @{ModuleName = 'toko-admin'; ModuleVersion = '1.1.0'; MaximumVersion = '1.*' },
        @{ModuleName = 'toko-posh-dev-tools'; ModuleVersion = '0.1.0'; MaximumVersion = '0.*' }
    )
    DefaultCommandPrefix = "Sf_"
    PrivateData       = @{
        PSData = @{
            ProjectUri   = 'https://github.com/todorm85/sitefinity-dev-orchestration'
            ReleaseNotes = @'
            3.0.0
                Powershell standards compliance - function names
                No Config type
                Add config global object
                Fixes for default tags
                Other bugfixes
            2.0.0
                When renaming to a title of AzureDevOps copied item title it is automatically recognized and processed.
                Clipboard is no longer modified when renaming a project.
                Fix: When restoring states user is prompted to select from available
                Less timeout for waiting Sitefinity to start
                Removed fluent api, no longr necessary to load module with using
                New Api and Renaming of Old Apis
                Fix: when delete project and removing from tool fails there is no validation for success.
            1.4.0            
                Fix: renaming a project does not change the console title
            1.3.5
                BUG Fix DbBackups not overriden
            1.3.4
                BUG fix Cannot get appDbName when more than one connection strings in data.config #52
                Fix error message when initializing the webapp older Sitefinity version #23
            1.3.3
                Fix fallback to opening webapppath when no solution
                Fix wrong build selected from prompt
            1.3.2
                Fix prompting for build path
            1.3.1            
                Fix Prompting for branches
                Fix states
                
            1.3.0
                Ability to create project from build path
            1.2.0
                (Project filtering by tags)[https://github.com/todorm85/sitefinity-dev-orchestration/issues/30]
                Persisted project updated with latest initialized data
            1.1.0
                Importing Web Application Folder is Broken - various errors
                Auto-detect website on import
                Auto-detect and update settings when loading project
                Improve error messages
                Check for workspace only at startup and stop showing the error
                Simplify fluent api
            Fixes
                Import project form directory is broken
                Add more functions to fluent
            1.0.1
            Fixes
                Better error handling when building solution
            1.0.0
            Improvements
                Fluent API remove clutter methods
                Fluent API project methods extracted to separate facades

            # 0.2.0
            Features
                Add fluent API
            Fixes
                Imported projects were not mapped to source control
                Improve error messages for misconfigurations

            0.1.2
            Removed globals in scope, extracted user configuration as separate API
            Optimized module size, external tools and low-level helpers extracted to separate module as dependency.

            0.1.1
            Some external tools are no longer prepackaged, but downloaded on demand.

            0.1.0
            Contains all features ready for production however requires more real life testing and usage.
'@
        }
    }
}
