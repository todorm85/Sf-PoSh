function _getFunctionNames {
    param(
        [bool]$exportPrivate
    )

    Get-ChildItem -Path "$PSScriptRoot\..\core" -File -Recurse | 
    Where-Object { $_.Extension -eq '.ps1' -and ($exportPrivate -or $_.Name -notlike "*.init.ps1") } | 
    Get-Content | Where-Object { $_.contains("function") } | 
    Where-Object { $_ -match "^\s*function\s+?(?<name>[\w-]+?)\s.*$" } | 
    ForEach-Object { $Matches["name"] } | Where-Object { $exportPrivate -or !$_.StartsWith("_") }
}

function _getLoadedModuleVersion {
    Get-Content -Path "$PSScriptRoot\..\version.txt"
}
