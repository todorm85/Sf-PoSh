<#
.SYNOPSIS
    Deploys the standalone Sitefinity scripts to the configured target folder.

.DESCRIPTION
    Mirrors scripts/standalone/* into the destination, preserving the lib/
    subfolder. Existing files are overwritten. Anything else already present
    in the destination is left untouched.

.PARAMETER TargetDir
    Override destination. Defaults to the SF_POSH_SCRIPTS_PATH environment
    variable when set, otherwise to
    C:\todor\cloud\OneDrive\progress\automation\ps\Scripts.
#>
[CmdletBinding()]
param(
    [string]$TargetDir
)

$ErrorActionPreference = 'Stop'

if (-not $TargetDir) {
    $TargetDir = if ($env:SF_POSH_SCRIPTS_PATH) {
        $env:SF_POSH_SCRIPTS_PATH
    } else {
        'C:\todor\cloud\OneDrive\progress\automation\ps\Scripts'
    }
}

$sourceDir = Resolve-Path (Join-Path $PSScriptRoot '..\scripts\standalone')

if (-not (Test-Path $TargetDir)) {
    New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null
}

# Remove any stale Sfs-*.ps1 from the destination (so renamed/deleted
# scripts don't linger). Only touches our own files; leaves anything else.
$currentNames = @(Get-ChildItem -Path $sourceDir -Filter 'Sfs-*.ps1' | Select-Object -ExpandProperty Name)
Get-ChildItem -Path $TargetDir -Filter 'Sfs-*.ps1' -ErrorAction SilentlyContinue |
    Where-Object { $currentNames -notcontains $_.Name } |
    ForEach-Object {
        Write-Host "Removing stale: $($_.FullName)"
        Remove-Item $_.FullName -Force
    }

Copy-Item -Path (Join-Path $sourceDir '*') -Destination $TargetDir -Recurse -Force

Write-Host "Standalone scripts deployed to $TargetDir"
