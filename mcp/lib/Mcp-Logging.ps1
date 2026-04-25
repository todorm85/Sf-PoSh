<#
.SYNOPSIS
    Stderr-only structured logging for the MCP server.

.DESCRIPTION
    The MCP stdio transport reserves stdout for protocol messages. Anything
    else written to stdout corrupts the JSON-RPC stream. All diagnostic
    output therefore goes to stderr via [Console]::Error.
#>

Set-StrictMode -Version Latest

$script:McpLogLevel = if ($env:SF_MCP_LOG_LEVEL) { $env:SF_MCP_LOG_LEVEL } else { 'info' }

$script:McpLogLevels = @{
    'debug' = 0
    'info'  = 1
    'warn'  = 2
    'error' = 3
}

function Write-McpLog {
    param(
        [Parameter(Mandatory)][ValidateSet('debug','info','warn','error')][string]$Level,
        [Parameter(Mandatory)][string]$Message
    )
    if ($script:McpLogLevels[$Level] -lt $script:McpLogLevels[$script:McpLogLevel]) { return }
    $ts = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffK')
    [Console]::Error.WriteLine("[$ts] [$($Level.ToUpper())] $Message")
}
