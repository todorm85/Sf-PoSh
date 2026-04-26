<#
.SYNOPSIS
    Internal: invokes a standalone Sfs-* script with a JSON-encoded
    parameter hashtable, and serializes its output to one line of
    compact JSON on stdout.

.DESCRIPTION
    Used by the MCP server to run a tool in a child pwsh process via
    `-File`. Parameters are passed as a single JSON object so they
    can be splatted as a hashtable (preserving names + types).

    Streams:
      - stdout: ONE line of compact JSON = the script's pipeline output
                ('null' if the script returned nothing).
      - stderr: line-prefixed channel:
                  '[progress] <text>'  -> Information / Progress records;
                                          parent forwards as MCP
                                          notifications/progress.
                  '[error]    <text>'  -> error records (kept for diagnostics).
                  any other line       -> raw stderr from the child.

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

function Write-ProgressLine {
    param([string]$Text)
    if ($null -eq $Text) { return }
    # MCP forbids embedded newlines in JSON-RPC frames; the parent will
    # forward this verbatim, so collapse internal newlines.
    $clean = ($Text -replace "`r", '' -replace "`n", ' ').Trim()
    if (-not $clean) { return }
    [Console]::Error.WriteLine("[progress] $clean")
    [Console]::Error.Flush()
}

try {
    $params = $ParamsJson | ConvertFrom-Json -AsHashtable
    if ($null -eq $params) { $params = @{} }

    $collected = New-Object System.Collections.Generic.List[object]

    # Merge streams 6 (Information) and 4 (Progress) and 2 (Error) into the
    # success pipeline so we can dispatch them by type without losing order.
    & $ScriptPath @params 2>&1 6>&1 4>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.InformationRecord]) {
            Write-ProgressLine -Text ([string]$_.MessageData)
        }
        elseif ($_ -is [System.Management.Automation.ProgressRecord]) {
            $pct = if ($_.PercentComplete -ge 0) { " $($_.PercentComplete)%" } else { '' }
            $status = if ($_.StatusDescription) { ": $($_.StatusDescription)" } else { '' }
            Write-ProgressLine -Text "$($_.Activity)$status$pct"
        }
        elseif ($_ -is [System.Management.Automation.ErrorRecord]) {
            [Console]::Error.WriteLine("[error] $($_.ToString())")
            [Console]::Error.Flush()
        }
        elseif ($_ -is [System.Management.Automation.WarningRecord]) {
            Write-ProgressLine -Text "WARNING: $($_.Message)"
        }
        else {
            $collected.Add($_)
        }
    }

    if ($collected.Count -eq 0) {
        'null'
    }
    elseif ($collected.Count -eq 1) {
        $collected[0] | ConvertTo-Json -Depth 10 -Compress
    }
    else {
        ,$collected.ToArray() | ConvertTo-Json -Depth 10 -Compress
    }
}
catch {
    $msg = $_.Exception.Message
    if (-not $msg) { $msg = [string]$_ }
    [Console]::Error.WriteLine("[error] $msg")
    exit 1
}

