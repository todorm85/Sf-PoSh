# $path = "$PSScriptRoot\..\sf-dev\core"
$path = "$PSScriptRoot\..\"

# $oldNames = Invoke-Expression "& `"$PSScriptRoot/get-Functions.ps1`" -path `"$path`""
$oldNames = @('data-getAllProjects', 'proj-setDescription', 'proj-getDescription', 'proj-new', 'proj-clone', 'proj-import', 'proj-removeBulk', 'proj-remove', 'proj-rename', 'proj-reset', 'proj-getCurrent', 'proj-setCurrent', 'proj-tags-add', 'proj-tags-remove', 'proj-tags-removeAll', 'proj-tags-getAll', 'proj-tags-setDefaultFilter', 'proj-tags-getDefaultFilter', 'proj-select', 'proj-show', 'proj-showAll', 'proj-tools-startAllProjectsBatch', 'proj-tools-clearAllProjectsLeftovers', 'proj-tools-goto', 'proj-tools-updateAllProjectsTfsInfo', 'sol-build', 'sol-rebuild', 'sol-clean', 'sol-clearPackages', 'sol-open', 'sol-buildWebAppProj', 'sol-unlockAllFiles', 'tfs-undoPendingChanges', 'tfs-showPendingChanges', 'tfs-hasPendingChanges', 'tfs-getLatestChanges', 'srv-pool-resetThread', 'srv-pool-resetPool', 'srv-pool-stopPool', 'srv-pool-changePool', 'srv-pool-getPoolId', 'srv-subApp-set', 'srv-subApp-remove', 'srv-site-rename', 'srv-site-open', 'srv-site-new', 'app-configs-setStorageMode', 'app-configs-getStorageMode', 'app-configs-getFromDb', 'app-configs-clearInDb', 'app-configs-setInDb', 'app-db-getName', 'app-db-setName', 'app-addPrecompiledTemplates', 'app-reset', 'app-states-save', 'app-states-restore', 'app-states-remove', 'app-states-removeAll')

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
