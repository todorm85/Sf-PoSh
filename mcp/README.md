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
| `build-sitefinity-app` | `Sfs-Build-SitefinityApp.ps1` | Build a Sitefinity solution / web app with optional restore + clean. |
| `create-sitefinity-app-iis-site` | `Sfs-Create-SitefinityAppIisSite.ps1` | Create an IIS site + app pool for a Sitefinity project on disk. |
| `ensure-running-sitefinity-app` | `Sfs-EnsureRunning-SitefinityApp.ps1` | Start the IIS site and wait for `/appstatus` to report ready. |
| `get-sitefinity-app-info` | `Sfs-Get-SitefinityAppInfo.ps1` | Resolve project metadata (URL, bindings, DB name, app pool, state). |
| `reset-sitefinity-app` | `Sfs-Reset-SitefinityApp.ps1` | Drop DB, clear App_Data, write fresh StartupConfig, wait for ready. |

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

## Configuration (env vars)

These env vars, when set on the MCP server process, become defaults for
tool arguments so the AI never has to pass them (and they never enter
the LLM context):

| Env var | Used by | Defaults |
| --- | --- | --- |
| `SF_SQL_SERVER` | `reset-sitefinity-app` | `-SqlServerInstance` |
| `SF_SQL_USER` | `reset-sitefinity-app` | `-SqlUser` |
| `SF_SQL_PASSWORD` | `reset-sitefinity-app` | `-SqlPassword` |
| `SF_MCP_LOG_LEVEL` | the server | log verbosity (`debug`/`info`/`warn`/`error`) |

Set them once in your MCP client's `env` block (see config examples
below). The child pwsh that runs each script inherits them automatically.

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

- Configure SQL credentials via `SF_SQL_SERVER` / `SF_SQL_USER` / `SF_SQL_PASSWORD`
  on the MCP server process (see *Configuration*). When supplied this way they
  stay in the server's environment and are NOT visible in the LLM context.
  If you instead pass them as tool arguments they will appear in the model's
  conversation — prefer the env vars.
- The Sitefinity admin user/password embedded in `Sfs-Reset-SitefinityApp.ps1`
  (`admin@test.test` / `admin@2`) are dev defaults; override per-call when needed.
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
