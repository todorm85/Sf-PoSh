<#
.SYNOPSIS
    sitefinity-app-dev-mcp: stdio MCP server exposing standalone Sitefinity
    app scripts as MCP tools.

.DESCRIPTION
    Reads newline-delimited JSON-RPC 2.0 messages from stdin, dispatches the
    supported MCP methods (initialize, tools/list, tools/call, ping), and
    writes responses to stdout. All diagnostics go to stderr.

    Supported MCP methods:
      - initialize
      - notifications/initialized
      - ping
      - tools/list
      - tools/call

    Cancellation, progress notifications, resources, and prompts are out of
    scope for v1.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib\Mcp-Logging.ps1')
. (Join-Path $PSScriptRoot 'lib\Mcp-Protocol.ps1')
. (Join-Path $PSScriptRoot 'lib\Mcp-Tools.ps1')

$script:ServerName    = 'sitefinity-app-dev-mcp'
$script:ServerVersion = '0.1.0'
$script:ProtocolVersion = '2025-06-18'
$script:Initialized   = $false

# Tool cache: name -> tool definition hashtable
$script:Tools = @{}
try {
    $defs = Get-SfMcpToolDefinitions
    foreach ($t in $defs) { $script:Tools[$t.name] = $t }
    Write-McpLog -Level info -Message "Loaded $($script:Tools.Count) tool(s): $($script:Tools.Keys -join ', ')"
}
catch {
    Write-McpLog -Level error -Message "Failed to load tools: $($_.Exception.Message)"
    throw
}

# Report which SF_SQL_* defaults are inherited from the launching MCP client.
# Values are intentionally NOT logged; presence only.
$sqlEnvStatus = foreach ($n in 'SF_SQL_SERVER','SF_SQL_USER','SF_SQL_PASSWORD') {
    $set = -not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($n))
    "${n}=$(if ($set) { 'set' } else { 'unset' })"
}
Write-McpLog -Level info -Message ("SQL env defaults: " + ($sqlEnvStatus -join ', '))

# ---------------------------------------------------------------------------
# Method handlers
# ---------------------------------------------------------------------------

function Invoke-Initialize {
    param($Params)
    $script:Initialized = $true
    return @{
        protocolVersion = $script:ProtocolVersion
        capabilities    = @{
            tools = @{ listChanged = $false }
        }
        serverInfo      = @{
            name    = $script:ServerName
            version = $script:ServerVersion
        }
    }
}

function Invoke-ToolsList {
    param($Params)
    $public = foreach ($t in $script:Tools.Values) { Get-PublicToolView -Tool $t }
    return @{ tools = @($public) }
}

function Invoke-ToolsCall {
    param($Params)

    if (-not $Params -or -not $Params.ContainsKey('name')) {
        throw [System.ArgumentException]::new("Missing 'name' parameter.")
    }
    $name = [string]$Params['name']
    $args = if ($Params.ContainsKey('arguments')) { $Params['arguments'] } else { @{} }

    if (-not $script:Tools.ContainsKey($name)) {
        return @{
            isError = $true
            content = @(@{ type = 'text'; text = "Unknown tool: '$name'." })
        }
    }

    $tool = $script:Tools[$name]
    try {
        $res = Invoke-SfMcpTool -Tool $tool -Arguments $args
    }
    catch {
        return @{
            isError = $true
            content = @(@{ type = 'text'; text = "Tool invocation failed: $($_.Exception.Message)" })
        }
    }

    if ($res.exitCode -ne 0) {
        $msg = "Tool '$name' exited with code $($res.exitCode)."
        if ($res.stderr) { $msg = "$msg`n$($res.stderr.Trim())" }
        return @{
            isError = $true
            content = @(@{ type = 'text'; text = $msg })
        }
    }

    $text = if ($res.stdout) { $res.stdout.Trim() } else { '' }
    return @{
        isError = $false
        content = @(@{ type = 'text'; text = $text })
    }
}

function Invoke-Ping {
    param($Params)
    return @{}
}

# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------

function Invoke-McpMessage {
    param([Parameter(Mandatory)][string]$Line)

    $msg = $null
    try {
        $msg = ConvertFrom-McpMessage -Line $Line
    }
    catch {
        Write-McpLog -Level warn -Message "Parse error: $($_.Exception.Message)"
        Write-McpMessage (New-McpErrorResponse -Id $null -Code $script:McpErrParse -Message 'Parse error')
        return
    }

    if (-not ($msg -is [hashtable]) -or -not $msg.ContainsKey('jsonrpc') -or $msg['jsonrpc'] -ne '2.0') {
        Write-McpMessage (New-McpErrorResponse -Id $null -Code $script:McpErrInvalidReq -Message 'Invalid JSON-RPC message')
        return
    }

    $id     = if ($msg.ContainsKey('id')) { $msg['id'] } else { $null }
    $method = if ($msg.ContainsKey('method')) { [string]$msg['method'] } else { $null }
    $params = if ($msg.ContainsKey('params')) { $msg['params'] } else { @{} }
    $isNotification = -not $msg.ContainsKey('id')

    if (-not $method) {
        # A response from the client; we don't currently send requests, so ignore.
        Write-McpLog -Level debug -Message "Ignoring message without method (id=$id)."
        return
    }

    Write-McpLog -Level debug -Message "Dispatch: method=$method id=$id notification=$isNotification"

    try {
        switch ($method) {
            'initialize' {
                $result = Invoke-Initialize -Params $params
                Write-McpMessage (New-McpResponse -Id $id -Result $result)
            }
            'notifications/initialized' {
                $script:Initialized = $true
                # No response for notifications.
            }
            'notifications/cancelled' {
                Write-McpLog -Level debug -Message "Received cancelled notification (ignored in v1)."
            }
            'ping' {
                Write-McpMessage (New-McpResponse -Id $id -Result (Invoke-Ping -Params $params))
            }
            'tools/list' {
                Write-McpMessage (New-McpResponse -Id $id -Result (Invoke-ToolsList -Params $params))
            }
            'tools/call' {
                Write-McpMessage (New-McpResponse -Id $id -Result (Invoke-ToolsCall -Params $params))
            }
            default {
                if (-not $isNotification) {
                    Write-McpMessage (New-McpErrorResponse -Id $id -Code $script:McpErrMethodNotFnd -Message "Method not found: $method")
                }
                else {
                    Write-McpLog -Level debug -Message "Ignoring unknown notification: $method"
                }
            }
        }
    }
    catch {
        Write-McpLog -Level error -Message "Handler error for method '$method': $($_.Exception.Message)`n$($_.ScriptStackTrace)"
        if (-not $isNotification) {
            Write-McpMessage (New-McpErrorResponse -Id $id -Code $script:McpErrInternal -Message "Internal error: $($_.Exception.Message)")
        }
    }
}

# ---------------------------------------------------------------------------
# Stdio loop
# ---------------------------------------------------------------------------

Write-McpLog -Level info -Message "$($script:ServerName) v$($script:ServerVersion) starting (protocol $($script:ProtocolVersion))."

while ($true) {
    $line = $null
    try {
        $line = Read-McpMessage
    }
    catch {
        Write-McpLog -Level error -Message "Read error: $($_.Exception.Message)"
        break
    }
    if ($null -eq $line) {
        Write-McpLog -Level info -Message 'Stdin closed; exiting.'
        break
    }
    if ([string]::IsNullOrWhiteSpace($line)) { continue }

    Invoke-McpMessage -Line $line
}
