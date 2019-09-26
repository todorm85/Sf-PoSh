# $path = "$PSScriptRoot\..\sf-dev\core"
$path = "$PSScriptRoot\..\"

# $oldNames = Invoke-Expression "& `"$PSScriptRoot/get-Functions.ps1`" -path `"$path`""
$oldNames = @('data_getAllProjects', 'proj_setDescription', 'proj_getDescription', 'proj_new', 'proj_clone', 'proj_import', 'proj_removeBulk', 'proj_remove', 'proj_rename', 'proj_reset', 'proj_getCurrent', 'proj_setCurrent', 'proj_tags_add', 'proj_tags_remove', 'proj_tags_removeAll', 'proj_tags_getAll', 'proj_tags_setDefaultFilter', 'proj_tags_getDefaultFilter', 'proj_select', 'proj_show', 'proj_showAll', 'proj_tools_startAllProjectsBatch', 'proj_tools_clearAllProjectsLeftovers', 'proj_tools_goto', 'proj_tools_updateAllProjectsTfsInfo', 'sol_build', 'sol_rebuild', 'sol_clean', 'sol_clearPackages', 'sol_open', 'sol_buildWebAppProj', 'sol_unlockAllFiles', 'tfs_undoPendingChanges', 'tfs_showPendingChanges', 'tfs_hasPendingChanges', 'tfs_getLatestChanges', 'srv_pool_resetThread', 'srv_pool_resetPool', 'srv_pool_stopPool', 'srv_pool_changePool', 'srv_pool_getPoolId', 'srv_subApp_set', 'srv_subApp_remove', 'srv_site_rename', 'srv_site_open', 'srv_site_new', 'app_configs_setStorageMode', 'app_configs_getStorageMode', 'app_configs_getFromDb', 'app_configs_clearInDb', 'app_configs_setInDb', 'app_db_getName', 'app_db_setName', 'app_addPrecompiledTemplates', 'app_reset', 'app_states_save', 'app_states_restore', 'app_states_remove', 'app_states_removeAll')

function Rename-Function {
    param (
        [string]$text
    )
    
    $text = $text.Replace("_", "");
    $result = "";
    $setCapital = $true;
    for ($i = 0; $i -lt $text.Length; $i++) {
        $letter = $text[$i]
        if ($setCapital) {
            $newResult = $letter.ToString().ToUpperInvariant();
        } else {
            $newResult = $letter
        }

        if ($letter -eq '-') {
            $setCapital = $true;
        } else {
            $result = "$result$newResult"
            $setCapital = $false;
        }
    }

    $result
}

$scripts = Get-ChildItem $path -Recurse | Where-Object { $_.Extension -eq '.ps1'}

$scripts | % { 
    $content = Get-Content $_.FullName
    $oldNames | % {
        # $newTitle = Rename-Function($_)
        [string]$oldName = [string]$_
        $newTitle = $oldName.Replace('_', '-')
        $content = $content -replace $oldName, $newTitle
    }

    $content | Set-Content -Path $_.FullName
}
