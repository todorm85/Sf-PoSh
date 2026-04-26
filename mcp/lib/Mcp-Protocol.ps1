<#
.SYNOPSIS
    JSON-RPC 2.0 framing helpers for the MCP stdio transport.

.DESCRIPTION
    Per the MCP spec (2025-06-18, stdio section):
      - Messages are newline-delimited UTF-8 JSON.
      - Messages MUST NOT contain embedded newlines.
      - stdout is reserved for protocol messages.
#>

Set-StrictMode -Version Latest

# JSON-RPC 2.0 standard error codes
$script:McpErrParse        = -32700
$script:McpErrInvalidReq   = -32600
$script:McpErrMethodNotFnd = -32601
$script:McpErrInvalidParam = -32602
$script:McpErrInternal     = -32603

function Read-McpMessage {
    <#
    .SYNOPSIS
        Reads a single newline-delimited JSON-RPC message from stdin.
        Returns $null on EOF.
    #>
    $line = [Console]::In.ReadLine()
    if ($null -eq $line) { return $null }
    return $line
}

function ConvertFrom-McpMessage {
    param([Parameter(Mandatory)][string]$Line)
    return $Line | ConvertFrom-Json -AsHashtable -Depth 32
}

function Write-McpMessage {
    <#
    .SYNOPSIS
        Serializes a hashtable / pscustomobject to compressed JSON and writes
        it to stdout followed by a newline. Flushes immediately.
    #>
    param([Parameter(Mandatory)]$Message)
    $json = $Message | ConvertTo-Json -Depth 32 -Compress
    # Defensive: strip any embedded CR/LF (spec forbids them).
    $json = $json -replace "`r", '' -replace "`n", ''
    [Console]::Out.WriteLine($json)
    [Console]::Out.Flush()
}

function New-McpResponse {
    param(
        [Parameter(Mandatory)]$Id,
        [Parameter(Mandatory)]$Result
    )
    return @{
        jsonrpc = '2.0'
        id      = $Id
        result  = $Result
    }
}

function New-McpProgressNotification {
    <#
    .SYNOPSIS
        Builds a 'notifications/progress' JSON-RPC notification frame.

    .DESCRIPTION
        Per MCP 2025-06-18, when a request includes 'params._meta.progressToken',
        the server MAY emit one or more 'notifications/progress' notifications
        carrying that same token until it sends the final response.

        Compliant clients reset their per-request timeout each time they
        receive a progress notification for an in-flight request, so this is
        the spec-blessed way to keep long-running tool calls from tripping
        client-side request timeouts (e.g. -32001).
    #>
    param(
        [Parameter(Mandatory)]$ProgressToken,
        [Parameter(Mandatory)][double]$Progress,
        [double]$Total,
        [string]$Message
    )
    $params = [ordered]@{
        progressToken = $ProgressToken
        progress      = $Progress
    }
    if ($PSBoundParameters.ContainsKey('Total')) { $params.total = $Total }
    if ($PSBoundParameters.ContainsKey('Message') -and $Message) { $params.message = $Message }
    return @{
        jsonrpc = '2.0'
        method  = 'notifications/progress'
        params  = $params
    }
}

function New-McpErrorResponse {
    param(
        $Id,
        [Parameter(Mandatory)][int]$Code,
        [Parameter(Mandatory)][string]$Message,
        $Data
    )
    $err = @{
        code    = $Code
        message = $Message
    }
    if ($PSBoundParameters.ContainsKey('Data') -and $null -ne $Data) {
        $err.data = $Data
    }
    return @{
        jsonrpc = '2.0'
        id      = $Id
        error   = $err
    }
}
