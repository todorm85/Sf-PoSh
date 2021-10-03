param(
    [bool]$exportPrivate
)

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
        }
        else {
            return $false
        }
    }

    return $false
}

$lastUpdatedVersionLoc = Get-ChildItem $PSScriptRoot -Directory | Sort-Object -Property CreationTime -Descending | Select -First 1
$currentModulePath = $lastUpdatedVersionLoc.FullName
$remotesPath = "\\filesrvbg01\Resources\Sitefinity\sf-posh"
$remoteLocation = Get-ChildItem -Path $remotesPath -Directory -ErrorAction SilentlyContinue | Sort-Object -Property CreationTime -Descending | Select -First 1
$currentVn = Get-Content -Path "$currentModulePath\version.txt" -ErrorAction SilentlyContinue
$remoteVn = Get-Content "$($remoteLocation.FullName)\version.txt" -ErrorAction SilentlyContinue
if ($remoteVn -and (!$currentVn -or (_isFirstVersionLower $currentVn $remoteVn))) {
    $update = Read-Host -Prompt "New module version detected. Update? - y/n"
    if ($update -eq 'y') {
        $remotePath = $remoteLocation.FullName
        $newModulePath = "$PSScriptRoot\$($remoteLocation.Name)"
        New-Item $newModulePath -ItemType Directory -Force
        Copy-Item "$remotePath\*" $newModulePath -Force -Recurse -ErrorVariable errorCopying
        if ($errorCopying) {
            Write-Warning "Error updating module. Error copying files locally: $errorCopying"
            Remove-Item $newModulePath -Force -Recurse
        }
        else {
            $currentModulePath = $newModulePath
            Write-Warning "Module updated."
            Get-ChildItem $PSScriptRoot -Directory | ? Name -ne $remoteLocation.Name | Remove-Item -Force -Recurse
        }
    }
}

if (!$currentModulePath) {
    throw "No local module available and no access to $remotesPath to download latest version."
}

. "$currentModulePath\load-module.ps1"

$public = _getFunctionNames -exportPrivate $exportPrivate
Export-ModuleMember -Function $public
