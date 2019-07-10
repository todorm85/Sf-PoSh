@{
    RootModule        = '.\sf-dev.psm1'
    GUID              = '570fb657-4d88-4883-8b39-2dae4db1280c'
    Author            = 'Todor Mitskovski'
    Copyright         = '(c) 2019 Todor Mitskovski. All rights reserved.'
    Description       = 'Manage Sitefinity instances on local machine. Docs: https://github.com/todorm85/sitefinity-dev-orchestration/blob/master/README.md'
    PowerShellVersion = '5.1'
    CLRVersion        = '4.0'
    FunctionsToExport = 'sf-start-allProjectsBatch', 'sf-start-batch', 'sf-set-description', 'sf-new-project', 'sf-clone-project', 'sf-import-project', 'sf-delete-projects', 'sf-delete-project', 'sf-rename-project', 'sf-update-allProjectsTfsInfo', 'sf-clean-allProjectsLeftovers', 'sf-reset-project', 'sf-select-project', 'sf-show-currentProject', 'sf-show-projects', 'sf-build-solution', 'sf-rebuild-solution', 'sf-clean-solution', 'sf-open-solution', 'sf-build-webAppProj', 'sf-unlock-allFiles', 'sf-switch-styleCop', 'sf-undo-pendingChanges', 'sf-show-pendingChanges', 'sf-get-hasPendingChanges', 'sf-get-latestChanges', 'sf-reset-thread', 'sf-reset-pool', 'sf-stop-pool', 'sf-change-pool', 'sf-get-poolId', 'sf-setup-asSubApp', 'sf-remove-subApp', 'sf-rename-website', 'sf-browse-webSite', 'sf-create-website', 'sf-goto', 'sf-set-storageMode', 'sf-get-storageMode', 'sf-get-configContentFromDb', 'sf-clear-configContentInDb', 'sf-insert-configContentInDb', 'sf-get-appDbName', 'sf-set-appDbName', 'sf-reset-app', 'sf-add-precompiledTemplates', 'sf-new-appState', 'sf-restore-appState', 'sf-delete-appState', 'sf-delete-allAppStates', 'sf-get-fluent', 'sf-clean-packages'
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = '*'
    ModuleVersion     = '1.3.5'
    RequiredModules   = @(
        @{ModuleName = 'toko-admin'; ModuleVersion = '0.3.0'; MaximumVersion = '0.*' },
        @{ModuleName = 'toko-posh-dev-tools'; ModuleVersion = '0.1.0'; MaximumVersion = '0.*' }
    )
    PrivateData       = @{
        PSData = @{
            ProjectUri   = 'https://github.com/todorm85/sitefinity-dev-orchestration'
            ReleaseNotes = @'
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
