@{
    RootModule        = '.\sf-posh.psm1'
    GUID              = '570fb657-4d88-4883-8b39-2dae4db1280c'
    Author            = 'Todor Mitskovski'
    Copyright         = '(c) 2019 Todor Mitskovski. All rights reserved.'
    Description       = 'Manage Sitefinity instances on local machine. Docs: https://github.com/todorm85/sitefinity-dev-orchestration/blob/master/README.md'
    PowerShellVersion = '5.1'
    CLRVersion        = '4.0'
    FunctionsToExport = 'sf-configModule-open', 'sf-project-setDescription', 'sf-project-getDescription', 'sf-project-new', 'sf-project-clone', 'sf-project-removeBulk', 'sf-project-remove', 'sf-project-rename', 'sf-project-getCurrent', 'sf-project-setCurrent', 'sf-project-getAll', 'sf-project-save', 'InProjectScope', 'sf-projectTags-setDefaultFilter', 'sf-projectTags-getDefaultFilter', 'sf-projectTags-addToDefaultFilter', 'sf-projectTags-removeFromDefaultFilter', 'sf-projectTags-getAll', 'sf-projectTags-addToCurrent', 'sf-projectTags-removeFromCurrent', 'sf-projectTags-removeAllFromCurrent', 'sf-projectTags-getAllFromCurrent', 'sf-project-select', 'sf-project-getInfo', 'sf', 'sf-sol-build', 'sf-sol-rebuild', 'sf-sol-clean', 'sf-sol-clearPackages', 'sf-sol-open', 'sf-sol-buildWebAppProj', 'sf-sol-unlockAllFiles', 'sf-sol-resetSitefinityFolder', 'sf-sourceControl-undoPendingChanges', 'sf-sourceControl-showPendingChanges', 'sf-sourceControl-hasPendingChanges', 'sf-sourceControl-getLatestChanges', 'sf-config-open', 'sf-config-save', 'sf-config-getOrCreateElement', 'sf-config-getOrCreateElementPath', 'sf-configStartup-remove', 'sf-configStartup-create', 'sf-configSystem-setSslOffload', 'sf-configSystem-setNlbUrls', 'sf-configWeb-setMachineKey', 'sf-configWeb-removeMachineKey', 'sf-bindings-add', 'sf-bindings-get', 'sf-bindings-remove', 'sf-bindings-getOrCreateLocalhostBinding', 'sf-bindings-getLocalhostBinding', 'sf-bindings-getLocalhostUrl', 'sf-iisAppPool-ResetThread', 'sf-iisAppPool-Reset', 'sf-iisAppPool-Stop', 'sf-iisSite-browse', 'sf-iisSite-new', 'sf-iisSite-delete', 'sf-iisSite-getSubAppName', 'sf-iisSubApp-set', 'sf-iisSubApp-remove', 'sf-iisSite-getBinding', 'sf-iisSite-setBinding', 'sf-iisSite-getUrl', 'sf-iisSite-changeDomain', 'sf-nlbData-get', 'sf-nlbData-add', 'sf-nlbData-remove', 'sf-nlbData-getProjectIds', 'sf-nlbData-getNlbIds', 'sf-nginx-reset', 'sf-nlb-getOtherNodes', 'sf-nlb-forAllNodes', 'sf-nlb-setSslOffloadForAll', 'sf-nlb-overrideOtherNodeConfigs', 'sf-nlb-resetAllNodes', 'sf-nlb-getUrl', 'sf-nlb-openNlbSite', 'sf-nlb-getNlbId', 'sf-nlb-newCluster', 'sf-nlb-removeCluster', 'sf-nlb-getStatus', 'sf-app-sendRequestAndEnsureInitialized', 'sf-app-initialize', 'sf-app-uninitialize', 'sf-app-reinitialize', 'sf-appPrecompiledTemplates-add', 'sf-appPrecompiledTemplates-remove', 'sf-app-isInitialized', 'sf-db-getNameFromDataConfig', 'sf-db-setNameInDataConfig', 'sf-serverCode-run', 'sf-appStates-save', 'sf-appStates-restore', 'sf-appStates-remove', 'sf-appStates-removeAll', 'sf-appStates-get', 'iis-website-create', 'iis-isPortFree', 'iis-new-subApp', 'iis-remove-subApp', 'iis-set-sitePath', 'iis-bindings-getAll', 'iis-find-site', 'iis-getFreePort', 'iis-site-isStarted', 'clear-nugetCache', 'os-popup-notification', 'os-test-isPortFree', 'execute-native', 'unlock-allFiles', 'os-hosts-add', 'os-hosts-get', 'os-hosts-remove', 'os-browseUrl', 'sql-delete-database', 'sql-rename-database', 'sql-get-dbs', 'sql-get-items', 'sql-update-items', 'sql-insert-items', 'sql-delete-items', 'sql-test-isDbNameDuplicate', 'sql-copy-db', 'sql-createDb', 'sql-createTable', 'tfs-get-workspaces', 'tf-query-workspaces', 'tfs-delete-workspace', 'tfs-create-workspace', 'tfs-create-mappings', 'tfs-checkout-file', 'tfs-get-latestChanges', 'tfs-undo-pendingChanges', 'tfs-show-pendingChanges', 'tfs-get-workspaceName', 'tfs-get-branchPath', 'tfs-get-lastWorkspaceChangeset'
    CmdletsToExport   = @()
    VariablesToExport = @()
    # !!! Performance issue with intellisense do not enable
    # AliasesToExport   = '*'
    ModuleVersion     = '23.0.1'
    RequiredModules   = @(
        @{ModuleName = 'SqlServer'; ModuleVersion = '21.1.18179'; MaximumVersion = '21.1.*' }
    )
    PrivateData       = @{
        PSData = @{
            ProjectUri   = 'https://github.com/todorm85/sitefinity-dev-orchestration'
            ReleaseNotes = @'
            23.0.1
                Bugfixes
            23.0.0
                NLB feature complete
            21.1.1
                Fix nlb uninstall when ap not initialized
            21.1.0
                sf-app-isInitialized added
            18.1.0
                NLB support
            17.3.0
                Ability to skip db cloning on project clone.
            17.2.0
                states improvements
                bugfixes
            17.0.3
                Performance states
            17.0.2
                Fix Precompilation
            17.0.1
                Tags are List
            17.0.0
                Breaking: SfProejct.daysSinceLastGet property removed, use GetDaysSinceLastGet method
            16.0.2
            15.5.1
                Bugfix last get latest broken
            15.4.1
                Default binding fixes and feature
            15.3.1
                Bugfixes cloning project and tests refactoring
            15.3.0
                sf-project-save added
                fix bindings for localhost
            15.2.1
                fix website browse
            15.2.0
                renaming improvements
                bugfixes
            15.1.0
                multiple bindings
            15.0.0
                Refactor APIs and bugfixes
            14.0.0
                Refactor APIs
            13.0.0
                tags improvements
                bugfixes
            12.1.2
                Bugfixes
            12.1.1
                Bugfixes
            12.1.0
                Introduce days since last get
                project-setCurrent accepts pipeline input and outputs to pipeline
            12.0.0
                Public api changes
            11.0.0
                Major public api refactoring
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
                api sf-sd-app-waitForSitefinityToStart
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
