@{
    RootModule        = '.\sf-dev.psm1'
    GUID              = '570fb657-4d88-4883-8b39-2dae4db1280c'
    Author            = 'Todor Mitskovski'
    Copyright         = '(c) 2019 Todor Mitskovski. All rights reserved.'
    Description       = 'Manage Sitefinity instances on local machine. Docs: https://github.com/todorm85/sitefinity-dev-orchestration/blob/master/README.md'
    PowerShellVersion = '5.1'
    CLRVersion        = '4.0'
    FunctionsToExport = 'sf-data-getAllProjects', 'sf-proj-setDescription', 'sf-proj-new', 'sf-proj-clone', 'sf-proj-removeBulk', 'sf-proj-remove', 'sf-proj-rename', 'sf-proj-reset', 'sf-proj-setCurrent', 'sf-proj-getCurrent', 'sf-proj-getDescription', 'sf-proj-tags-addToCurrent', 'sf-proj-tags-removeFromCurrent', 'sf-proj-tags-removeAllFromCurrent', 'sf-proj-tags-getAll', 'sf-proj-tags-setDefaultFilter', 'sf-proj-tags-getDefaultFilter', 'sf-proj-select', 'sf-proj-show', 'sf-proj-showAll', 'sf-sol-build', 'sf-sol-rebuild', 'sf-sol-clean', 'sf-sol-clearPackages', 'sf-sol-open', 'sf-sol-buildWebAppProj', 'sf-sol-unlockAllFiles', 'sf-tfs-undoPendingChanges', 'sf-tfs-showPendingChanges', 'sf-tfs-hasPendingChanges', 'sf-tfs-getLatestChanges', 'sf-iis-pool-resetThread', 'sf-iis-pool-reset', 'sf-iis-pool-stop', 'sf-iis-pool-change', 'sf-iis-subApp-set', 'sf-iis-subApp-remove', 'sf-iis-site-rename', 'sf-iis-site-open', 'sf-iis-site-new', 'sf-app-configs-setStorageMode', 'sf-app-configs-getStorageMode', 'sf-app-configs-getFromDb', 'sf-app-configs-clearInDb', 'sf-app-configs-setInDb', 'sf-app-db-getName', 'sf-app-db-setName', 'sf-app-reset', 'sf-app-addPrecompiledTemplates', 'sf-app-states-save', 'sf-app-states-restore', 'sf-app-states-remove', 'sf-app-states-removeAll', 'sf-app-start', 'unlock-allFiles', 'os-hosts-add', 'os-hosts-remove', 'os-popup-notification', 'sf-proj-getAll', 'os-hosts-get'
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = '*'
    ModuleVersion     = '10.2.4'
    RequiredModules   = @(
        @{ModuleName = 'SqlServer'; ModuleVersion = '21.1.18179'; MaximumVersion = '21.1.*' }
    )
    PrivateData       = @{
        PSData = @{
            ProjectUri   = 'https://github.com/todorm85/sitefinity-dev-orchestration'
            ReleaseNotes = @'
            10.2.4 (new)
                autocomplete for tags when selecting project
                Fixed hosts file operations
                New names of hosts file functions
            10.2.3
                Remove unnecessary private functions
                Fixed predefined source path select
            10.2.2
                Renaming a project hangs #100
            10.2.1
                add sf-proj-getAll
            10.1.1
                Remove import web administration
            9.3.1
                Removed unused functions
                Refactoring of sql api, no more global state object
                Remove unused functions
                Add hosts file functions to API
            9.2.2
                Removed dependencies to toko-admin and toko-posh-dev-tools
            9.2.1
                api sf-app-start
                bug fixes
            9.1.5
                Bugfix: Error log not displayed when build fails
            9.1.4
                Bugfix: Undoing pending changes
            9.1.3
                Bugfix: Undoing pending changes
            9.1.2
                sf-proj-reset always resets not only when old project
            9.1.1
                sf-proj-new now can use existing app path. Removed sf-proj-import.
            8.2.2
                Major refacotring and improved error handling
            8.2.1
                progress bar for sitefinity initialization #87
            8.1.1
                Tags autocomplete #81
                Ability to list all projects when passing special switch #89
                Performance: Slow listing when removing bulk
                Fixed function names
            7.3.1
                importing app should save original app data folder #85
            7.3.0
                Ability to import directly from path to zip
                Auto discover of solution from zip
            7.2.0
                Default tags filter is applied to new projects
            7.1.3
                Fix corrupted definition file.
            7.1.2
                Fix building without solution.
            7.1.1
                Fix get latest changes
            7.1.0
                Expose remove bulk function
            7.0.0
                renamed iis public api
            6.0.0
                Public api with prefix sf- and dashes
            5.0.0
                !!! This version is broken, public api was not exposed in definition file
                Remove default command prefix
                Change public api functions to use dashes not underscores
            4.0.0
                New function naming convention
                Added default prefix for module
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
