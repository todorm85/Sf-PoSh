$scripts = @(
    # upgrade projects with not cached branch and site name when upgrading to 15.5.0
    { 
        param($oldVersion)
        if ((_isFirstVersionLower $oldVersion "15.5.0")) {
            sf-project-get -all | % { _proj-initialize $_; }
        }
        if ((_isFirstVersionLower $oldVersion "15.5.1")) {
            sf-project-get -all | % { _proj-initialize $_; }
        }
        if ((_isFirstVersionLower $oldVersion "16.0.3")) {
            $data = New-Object XML
            $data.Load($GLOBAL:sf.Config.dataPath)
            $data.data.RemoveAttribute('version')
            $data.Save($GLOBAL:sf.Config.dataPath) > $null
        }
        if ((_isFirstVersionLower $oldVersion "24.1.7")) {
            $data = New-Object XML
            $data.Load($GLOBAL:sf.Config.dataPath)
            $data.data.sitefinities.sitefinity | % {
                $_.SetAttribute("lastGetLatest", "")
            }

            $data.Save($GLOBAL:sf.Config.dataPath) > $null
        }
    }
)

function _upgrade {
    param (
        [ScriptBlock[]]$upgradeScripts
    )

    $oldVersion = _getModuleVersionFromDb
    if (!$oldVersion) {
        $oldVersion = "0.0.0"
    }

    $newVersion = _getLoadedModuleVersion
    if (!$newVersion) {
        throw "Could not detect new version for upgrade in psd file"
    }

    $upgradeScripts | % { 
        try {
            Invoke-Command -ScriptBlock $_ -ArgumentList $oldVersion
        }
        catch {
            Write-Warning "Upgrade error occured $_"
        }
    }
    
    _updateModuleVersionInSfDevData $newVersion
}

function _getModuleVersionFromDb {
    $data = New-Object XML
    $data.Load($GLOBAL:sf.Config.dataPath) > $null
    $versionData = $data.data.GetAttribute("moduleVersion")
    return $versionData
}

function _updateModuleVersionInSfDevData {
    param (
        [ValidatePattern({^\d+\.\d+\.\d+$})]$v
    )

    if (!$v) {
        throw "Invalid module version to update sfdev data."
    }

    $data = New-Object XML
    $data.Load($GLOBAL:sf.Config.dataPath) > $null
    $data.data.SetAttribute("moduleVersion", $v)
    $data.Save($GLOBAL:sf.Config.dataPath) > $null
}

_upgrade -upgradeScripts $scripts