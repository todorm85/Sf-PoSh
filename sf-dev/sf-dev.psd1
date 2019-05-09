@{
    RootModule        = '.\sf-dev.psm1'
    GUID              = '570fb657-4d88-4883-8b39-2dae4db1280c'
    Author            = 'Todor Mitskovski'
    Copyright         = '(c) 2019 Todor Mitskovski. All rights reserved.'
    Description       = 'Sitefinity core dev automation tools'
    PowerShellVersion = '5.1'
    CLRVersion        = '4.0'
    FunctionsToExport = 'sf-select-container', 'sf-create-container', 'sf-delete-container', 'sf-set-projectContainer', 'sf-start-allProjectsBatch', 'sf-start-batch', 'sf-set-description', 'sf-new-project', 'sf-clone-project', 'sf-import-project', 'sf-delete-projects', 'sf-delete-project', 'sf-rename-project', 'sf-update-allProjectsTfsInfo', 'sf-clean-allProjectsLeftovers', 'sf-reset-project', 'sf-select-project', 'sf-show-currentProject', 'sf-show-projects', 'sf-build-solution', 'sf-rebuild-solution', 'sf-clean-solution', 'sf-open-solution', 'sf-build-webAppProj', 'sf-unlock-allFiles', 'sf-switch-styleCop', 'sf-undo-pendingChanges', 'sf-show-pendingChanges', 'sf-get-hasPendingChanges', 'sf-get-latestChanges', 'sf-reset-thread', 'sf-reset-pool', 'sf-stop-pool', 'sf-change-pool', 'sf-get-poolId', 'sf-setup-asSubApp', 'sf-remove-subApp', 'sf-rename-website', 'sf-browse-webSite', 'sf-create-website', 'sf-goto', 'sf-set-storageMode', 'sf-get-storageMode', 'sf-get-configContentFromDb', 'sf-clear-configContentInDb', 'sf-insert-configContentInDb', 'sf-get-appDbName', 'sf-set-appDbName', 'sf-reset-app', 'sf-add-precompiledTemplates', 'sf-new-appState', 'sf-restore-appState', 'sf-delete-appState', 'sf-delete-allAppStates', 'sf-get-fluent', 'sf-clean-packages'
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = '*'
    ModuleVersion     = '1.0.0'
    RequiredModules   = @(
        @{ModuleName = 'toko-admin'; ModuleVersion = '0.2.0'; MaximumVersion = '0.*' },
        @{ModuleName = 'toko-posh-dev-tools'; ModuleVersion = '0.1.0'; MaximumVersion = '0.*' }
    )
    PrivateData       = @{
        PSData = @{
            ProjectUri   = 'https://github.com/todorm85/sitefinity-dev-orchestration'
            ReleaseNotes = @'
## 1.0.0
Improvements
    Fluent API remove clutter methods
    Fluent API project methods extracted to separate facades

# 0.2.0
Features
    Add fluent API
Fixes
    Imported projects were not mapped to source control
    Improve error messages for misconfigurations

## 0.1.2
Removed globals in scope, extracted user configuration as separate API
Optimized module size, external tools and low-level helpers extracted to separate module as dependency.

## 0.1.1
Some external tools are no longer prepackaged, but downloaded on demand.

## 0.1.0
Contains all features ready for production however requires more real life testing and usage.
'@
        }
    }
}
