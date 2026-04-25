# sitefinity-app-dev-mcp

A [Model Context Protocol](https://modelcontextprotocol.io) (MCP) server that
exposes the standalone Sitefinity-app dev scripts under
[`scripts/standalone/`](../scripts/standalone) as MCP tools, so AI assistants
(VS Code Copilot, Claude Desktop, Cursor, etc.) can drive Sitefinity local
dev workflows directly.

Hand-rolled PowerShell over stdio. No external runtime dependencies.

## Tools

| Tool name | Underlying script | Purpose |
| --- | --- | --- |
| `create-sitefinity-app-iis-site` | `Sfs-Create-SitefinityAppIisSite.ps1` | Create an IIS site + app pool for a Sitefinity project on disk. |
| `ensure-running-sitefinity-app` | `Sfs-EnsureRunning-SitefinityApp.ps1` | Start the site, ensure DB / startup config, wait for `/appstatus`. |
| `get-sitefinity-app-info` | `Sfs-Get-SitefinityAppInfo.ps1` | Resolve project metadata (URL, bindings, DB name, app pool, state). |
| `reinitialize-sitefinity-app` | `Sfs-Reinitialize-SitefinityApp.ps1` | Drop DB, clear App_Data, write fresh StartupConfig, wait for ready. |

Tool input schemas are auto-generated from each script's `param()` block and
comment-based help via the PowerShell AST. To add a new tool, drop a new
`Sfs-*.ps1` script into `scripts/standalone/` and restart the server.

## Prerequisites

- Windows
- PowerShell 7+
- IIS with `Microsoft.Web.Administration.dll`
- `SqlServer` PowerShell module (only for `ensure-running` / `reinitialize`)
- The pwsh process must run **as Administrator** for IIS / hosts-file edits

The server itself has no extra dependencies. The above are required by the
underlying scripts.

## Run manually

```pwsh
pwsh -NoProfile -File <repo>/mcp/Start-SfMcpServer.ps1
```

The server reads JSON-RPC 2.0 messages (one per line) on stdin and writes
responses on stdout. All diagnostics go to stderr.

Set `SF_MCP_LOG_LEVEL=debug` for verbose logs.

## Register with VS Code

Add to your workspace `.vscode/mcp.json` (or User Settings JSON):

```json
{
  "servers": {
    "sitefinity-app-dev": {
      "type": "stdio",
      "command": "pwsh",
      "args": [
        "-NoProfile",
        "-File",
        "C:/todor/repos/Sf-PoSh/mcp/Start-SfMcpServer.ps1"
      ]
    }
  }
}
```

See [`client-config-examples/vscode-mcp.json`](client-config-examples/vscode-mcp.json).

## Register with Claude Desktop

In `%APPDATA%/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "sitefinity-app-dev": {
      "command": "pwsh",
      "args": [
        "-NoProfile",
        "-File",
        "C:/todor/repos/Sf-PoSh/mcp/Start-SfMcpServer.ps1"
      ]
    }
  }
}
```

See [`client-config-examples/claude-desktop.json`](client-config-examples/claude-desktop.json).

## Security

- **Credentials are passed through tool arguments.** SQL and Sitefinity
  passwords appear in the tool input schema and flow through the LLM context
  when the agent calls the tool. Do **not** point this server at anything
  you wouldn't already trust the LLM client and its provider with.
- The server only spawns the scripts under `scripts/standalone/` discovered
  at startup. New scripts added at runtime are not picked up until restart.
- No HTTP transport is exposed. stdio only.

## Protocol scope (v1)

Implemented:

- `initialize`, `notifications/initialized`
- `ping`
- `tools/list`, `tools/call`

Not implemented:

- Cancellation (`notifications/cancelled` is accepted but ignored)
- Progress notifications
- Resources, prompts, sampling
- HTTP / SSE transport
