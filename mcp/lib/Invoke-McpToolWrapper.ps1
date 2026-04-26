<#
.SYNOPSIS
    Internal: invokes a standalone Sfs-* script with a JSON-encoded
    parameter hashtable, and serializes its output to one line of
    compact JSON on stdout.

.DESCRIPTION
    Used by the MCP server to run a tool in a child pwsh process via
    `-File`. Parameters are passed as a single JSON object so they
    can be splatted as a hashtable (preserving names + types).

    Behavior:
      - On success with output:    writes one line of compact JSON to stdout, exit 0.
      - On success with no output: writes 'null' to stdout, exit 0.
      - On failure:                writes the exception message to stderr, exit 1.

    $ErrorActionPreference is set to 'Stop' so non-terminating errors
    surface as a non-zero exit.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ScriptPath,
    [string]$ParamsJson = '{}'
)

$ErrorActionPreference = 'Stop'

try {
    $params = $ParamsJson | ConvertFrom-Json -AsHashtable
    if ($null -eq $params) { $params = @{} }

    $out = & $ScriptPath @params

    if ($null -ne $out) {
        $out | ConvertTo-Json -Depth 10 -Compress
    }
    else {
        'null'
    }
}
catch {
    $msg = $_.Exception.Message
    if (-not $msg) { $msg = [string]$_ }
    [Console]::Error.WriteLine($msg)
    exit 1
}
