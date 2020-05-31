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

$currentModulePath = "$PSScriptRoot"
$latestModulesRootPath = "$PSScriptRoot\latest"
if (Test-Path $latestModulesRootPath) {
    $lastUpdatedVersionLoc = Get-ChildItem $latestModulesRootPath | Sort-Object -Property CreationTime -Descending | Select -First 1
    if ($lastUpdatedVersionLoc) {
        $currentModulePath = $lastUpdatedVersionLoc.FullName
    }
}

$remotesPath = "\\tmitskov\sf-posh"
$remoteLocation = Get-ChildItem -Path $remotesPath -Directory | Sort-Object -Property CreationTime -Descending | Select -First 1
if ($remoteLocation) {
    $currentVn = Get-Content -Path "$currentModulePath\version.txt"
    $remoteVn = Get-Content "$($remoteLocation.FullName)\version.txt"
    if (_isFirstVersionLower $currentVn $remoteVn) {
        Write-Warning "New module version detected. Updating."
        $remotePath = $remoteLocation.FullName
        $newModulePath = "$latestModulesRootPath\$($remoteLocation.Name)"
        New-Item $newModulePath -Force -Directory
        Copy-Item "$remotePath\*" $newModulePath -Force -Recurse -ErrorVariable error
        if ($error) {
            Write-Warning "Error updating module."
            Remove-Item $newModulePath -Force -Recurse
        }
        else {
            $currentModulePath = $newModulePath
            Write-Warning "Module updated."
            Get-ChildItem $latestModulesRootPath | ? Name -NE $remoteLocation.Name | Remove-Item -Force -Recurse
        }
    }
}

. "$currentModulePath\load-module.ps1"

$public = _getFunctionNames
Export-ModuleMember -Function $public
