<#
.SYNOPSIS
    Deploys the sitefinity-app-dev-mcp server to the configured target folder.

.DESCRIPTION
    Mirrors mcp/* into the destination, preserving the lib/ and
    client-config-examples/ subfolders. Existing files are overwritten.
    Anything else already present in the destination is left untouched.

.PARAMETER TargetDir
    Override destination. Defaults to the SF_POSH_MCP_PATH environment
    variable when set, otherwise to
    C:\todor\cloud\OneDrive\progress\automation\mcp.
#>
[CmdletBinding()]
param(
    [string]$TargetDir
)

$ErrorActionPreference = 'Stop'

if (-not $TargetDir) {
    $TargetDir = if ($env:SF_POSH_MCP_PATH) {
        $env:SF_POSH_MCP_PATH
    } else {
        'C:\todor\cloud\OneDrive\progress\automation\mcp'
    }
}

$sourceDir = Resolve-Path (Join-Path $PSScriptRoot '..\mcp')

if (-not (Test-Path $TargetDir)) {
    New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null
}

Copy-Item -Path (Join-Path $sourceDir '*') -Destination $TargetDir -Recurse -Force

Write-Host "MCP server deployed to $TargetDir"
