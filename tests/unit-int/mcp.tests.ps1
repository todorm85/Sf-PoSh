# Tests for the hand-rolled MCP server under mcp/.
# These tests are self-contained: they do NOT load the sf-posh module.
# They cover:
#   - AST-based tool discovery
#   - JSON-RPC framing helpers
#   - End-to-end stdio handshake against a child pwsh process

BeforeAll {
    $script:mcpRoot      = (Resolve-Path (Join-Path $PSScriptRoot '..\..\mcp')).Path
    $script:serverScript = Join-Path $script:mcpRoot 'Start-SfMcpServer.ps1'

    . (Join-Path $script:mcpRoot 'lib\Mcp-Logging.ps1')
    . (Join-Path $script:mcpRoot 'lib\Mcp-Protocol.ps1')
    . (Join-Path $script:mcpRoot 'lib\Mcp-Tools.ps1')
}

Describe 'Mcp-Tools: discovery' {
    BeforeAll {
        $script:tools = @(Get-SfMcpToolDefinitions)
        $script:byName = @{}
        foreach ($t in $script:tools) { $script:byName[$t.name] = $t }
    }

    It 'discovers exactly the 4 standalone scripts' {
        $script:tools.Count | Should -Be 4
        $script:byName.Keys | Sort-Object | Should -Be @(
            'create-sitefinity-app-iis-site',
            'ensure-running-sitefinity-app',
            'get-sitefinity-app-info',
            'reinitialize-sitefinity-app'
        )
    }

    It 'maps [int] parameters to JSON Schema "integer"' {
        $tool = $script:byName['create-sitefinity-app-iis-site']
        $tool.inputSchema.properties['Port'].type | Should -Be 'integer'
    }

    It 'maps [switch] parameters to JSON Schema "boolean"' {
        $tool = $script:byName['reinitialize-sitefinity-app']
        $tool.inputSchema.properties['SkipEnsureRunning'].type | Should -Be 'boolean'
    }

    It 'preserves literal default values' {
        $tool = $script:byName['ensure-running-sitefinity-app']
        $tool.inputSchema.properties['TotalWaitSeconds'].default | Should -Be 180
    }

    It 'collects [Parameter(Mandatory)] params into required[]' {
        $tool = $script:byName['reinitialize-sitefinity-app']
        $tool.inputSchema.required | Should -Contain 'ProjectRoot'
        $tool.inputSchema.required | Should -Contain 'SqlPassword'
        $tool.inputSchema.required | Should -Contain 'SitefinityPassword'
        $tool.inputSchema.required | Should -Not -Contain 'DbName'
        $tool.inputSchema.required | Should -Not -Contain 'SkipEnsureRunning'
    }

    It 'sets additionalProperties=false on every tool' {
        foreach ($t in $script:tools) {
            $t.inputSchema.additionalProperties | Should -Be $false
        }
    }

    It 'pulls .SYNOPSIS into the tool description' {
        $tool = $script:byName['get-sitefinity-app-info']
        $tool.description | Should -Match 'Returns detailed info'
    }

    It 'pulls .PARAMETER help into property descriptions when present' {
        $tool = $script:byName['create-sitefinity-app-iis-site']
        $tool.inputSchema.properties['ProjectRoot'].description | Should -Match 'Sitefinity project'
    }
}

Describe 'Mcp-Protocol: framing helpers' {
    It 'New-McpResponse produces a valid JSON-RPC response shape' {
        $r = New-McpResponse -Id 7 -Result @{ ok = $true }
        $r.jsonrpc | Should -Be '2.0'
        $r.id      | Should -Be 7
        $r.result.ok | Should -Be $true
    }

    It 'New-McpErrorResponse produces a valid JSON-RPC error shape' {
        $r = New-McpErrorResponse -Id 9 -Code -32601 -Message 'Method not found'
        $r.error.code    | Should -Be -32601
        $r.error.message | Should -Be 'Method not found'
        $r.id            | Should -Be 9
    }
}

Describe 'Mcp-Tools: ConvertTo-McpKebabName' {
    It 'kebab-cases mixed-case PascalCase script names' {
        ConvertTo-McpKebabName -BaseName 'Sfs-Create-SitefinityAppIisSite' |
            Should -Be 'sfs-create-sitefinity-app-iis-site'
    }
}

Describe 'End-to-end stdio handshake' {
    BeforeAll {
        $script:pwshExe = (Get-Process -Id $PID).Path

        function Invoke-McpServerWithLines {
            param([Parameter(Mandatory)][string[]]$Lines)
            $stdinText = ($Lines -join "`n") + "`n"

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $script:pwshExe
            $psi.ArgumentList.Add('-NoProfile')
            $psi.ArgumentList.Add('-File')
            $psi.ArgumentList.Add($script:serverScript)
            $psi.RedirectStandardInput  = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError  = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow  = $true

            $proc = [System.Diagnostics.Process]::Start($psi)
            $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
            $stderrTask = $proc.StandardError.ReadToEndAsync()
            $proc.StandardInput.Write($stdinText)
            $proc.StandardInput.Close()
            if (-not $proc.WaitForExit(30000)) {
                $proc.Kill()
                throw "MCP server did not exit within 30s."
            }
            return @{
                stdout   = $stdoutTask.GetAwaiter().GetResult()
                stderr   = $stderrTask.GetAwaiter().GetResult()
                exitCode = $proc.ExitCode
            }
        }

        function ConvertFrom-NdJson {
            param([string]$Text)
            if (-not $Text) { return ,@() }
            $lines = $Text -split "`r?`n" | Where-Object { $_ -and -not [string]::IsNullOrWhiteSpace($_) }
            $items = foreach ($l in $lines) { $l | ConvertFrom-Json -AsHashtable -Depth 32 }
            # Wrap with comma to prevent single-element array unwrapping at the call site.
            return ,@($items)
        }
    }

    It 'responds to initialize with correct serverInfo and capabilities' {
        $res = Invoke-McpServerWithLines -Lines @(
            '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}'
        )
        $msgs = ConvertFrom-NdJson -Text $res.stdout
        $msgs.Count | Should -Be 1
        $msgs[0].id | Should -Be 1
        $msgs[0].result.serverInfo.name | Should -Be 'sitefinity-app-dev-mcp'
        $msgs[0].result.protocolVersion | Should -Be '2025-06-18'
        $msgs[0].result.capabilities.tools.listChanged | Should -Be $false
    }

    It 'lists 4 tools via tools/list' {
        $res = Invoke-McpServerWithLines -Lines @(
            '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}',
            '{"jsonrpc":"2.0","method":"notifications/initialized"}',
            '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
        )
        $msgs = ConvertFrom-NdJson -Text $res.stdout
        $listResp = $msgs | Where-Object { $_.id -eq 2 } | Select-Object -First 1
        $listResp | Should -Not -BeNullOrEmpty
        $listResp.result.tools.Count | Should -Be 4
        ($listResp.result.tools | ForEach-Object { $_.name }) |
            Should -Contain 'get-sitefinity-app-info'
    }

    It 'returns -32601 for an unknown method' {
        $res = Invoke-McpServerWithLines -Lines @(
            '{"jsonrpc":"2.0","id":99,"method":"does/not/exist"}'
        )
        $msgs = ConvertFrom-NdJson -Text $res.stdout
        $msgs[0].error.code | Should -Be -32601
    }

    It 'returns isError=true result for an unknown tool' {
        $res = Invoke-McpServerWithLines -Lines @(
            '{"jsonrpc":"2.0","id":42,"method":"tools/call","params":{"name":"no-such-tool","arguments":{}}}'
        )
        $msgs = ConvertFrom-NdJson -Text $res.stdout
        $msgs[0].result.isError | Should -Be $true
        $msgs[0].result.content[0].type | Should -Be 'text'
        $msgs[0].result.content[0].text | Should -Match 'Unknown tool'
    }

    It 'survives malformed JSON and replies with -32700' {
        $res = Invoke-McpServerWithLines -Lines @(
            'not valid json',
            '{"jsonrpc":"2.0","id":5,"method":"ping"}'
        )
        $msgs = ConvertFrom-NdJson -Text $res.stdout
        $msgs.Count | Should -Be 2
        $msgs[0].error.code | Should -Be -32700
        $msgs[1].id | Should -Be 5
        # Ping result is an empty object {} per spec; assert presence of the key, not non-emptiness.
        $msgs[1].ContainsKey('result') | Should -Be $true
    }
}
