function _upgrade {
    param (
        [ScriptBlock[]]$upgradeScripts
    )

    $oldVersion = _getExistingModuleVersion
    if (!$oldVersion) {
        $oldVersion = "0.0.0"
    }

    $newVersion = _getNewModuleVersion
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

function _getExistingModuleVersion {
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

function _isFirstVersionLower {
    param (
        [ValidatePattern({^\d+\.\d+\.\d+$})]$first,
        [ValidatePattern({^\d+\.\d+\.\d+$})]$second
    )
    
    $firstParts = $first.Split('.')
    $secondParts = $second.Split('.')
    for ($i = 0; $i -lt 3; $i++) {
        if ([int]::Parse($firstParts[$i]) -eq [int]::Parse($secondParts[$i])) {
            continue
        }

        if ([int]::Parse($firstParts[$i]) -lt [int]::Parse($secondParts[$i])) {
            return $true    
        } else {
            return $false
        }
    }

    return $false
}