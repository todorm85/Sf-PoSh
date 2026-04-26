<#
.SYNOPSIS
    Discovery and invocation of standalone Sitefinity scripts as MCP tools.

.DESCRIPTION
    Each scripts/standalone/Sfs-*.ps1 file is exposed as an MCP tool. The
    tool's input schema is derived from the script's param() block via the
    PowerShell AST. The tool's description and per-property descriptions are
    pulled from the script's comment-based help (.SYNOPSIS / .PARAMETER X).

    Tool execution shells the script in a child pwsh process and returns
    its output (piped through ConvertTo-Json) as the MCP tool result.
#>

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'Mcp-Logging.ps1')

# ---------------------------------------------------------------------------
# AST helpers
# ---------------------------------------------------------------------------

function ConvertTo-McpKebabName {
    param([Parameter(Mandatory)][string]$BaseName)
    # 'Sfs-Create-SitefinityAppIisSite' -> 'sfs-create-sitefinity-app-iis-site'
    $kebab = [regex]::Replace($BaseName, '([a-z0-9])([A-Z])', '$1-$2')
    $kebab = [regex]::Replace($kebab, '([A-Z]+)([A-Z][a-z])', '$1-$2')
    return $kebab.ToLowerInvariant()
}

function ConvertTo-McpJsonSchemaType {
    param([type]$Type)
    if ($null -eq $Type) { return @{ type = 'string' } }
    switch ($Type.FullName) {
        'System.String'   { return @{ type = 'string' } }
        'System.Int32'    { return @{ type = 'integer' } }
        'System.Int64'    { return @{ type = 'integer' } }
        'System.Int16'    { return @{ type = 'integer' } }
        'System.UInt32'   { return @{ type = 'integer' } }
        'System.Double'   { return @{ type = 'number' } }
        'System.Single'   { return @{ type = 'number' } }
        'System.Decimal'  { return @{ type = 'number' } }
        'System.Boolean'  { return @{ type = 'boolean' } }
        'System.Management.Automation.SwitchParameter' { return @{ type = 'boolean' } }
        default {
            if ($Type.IsArray) {
                $elem = ConvertTo-McpJsonSchemaType -Type $Type.GetElementType()
                return @{ type = 'array'; items = $elem }
            }
            return @{ type = 'string' }
        }
    }
}

function Get-McpToolDefinitionFromScript {
    param([Parameter(Mandatory)][string]$ScriptPath)

    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        throw "Parse errors in '$ScriptPath': $($errors | ForEach-Object { $_.Message } | Out-String)"
    }

    $paramBlock = $ast.ParamBlock
    if (-not $paramBlock) {
        throw "No param() block in '$ScriptPath'."
    }

    $help = $ast.GetHelpContent()
    $synopsis = $null
    $description = $null
    $paramHelp = @{}
    if ($help) {
        $synopsis    = $help.Synopsis
        $description = $help.Description
        if ($help.Parameters) { $paramHelp = $help.Parameters }
    }

    $properties = [ordered]@{}
    $required   = New-Object System.Collections.Generic.List[string]
    $paramMeta  = [ordered]@{}

    foreach ($p in $paramBlock.Parameters) {
        $name = $p.Name.VariablePath.UserPath
        $type = $p.StaticType
        $schema = ConvertTo-McpJsonSchemaType -Type $type

        $isMandatory = $false
        $isSwitch    = ($type -eq [System.Management.Automation.SwitchParameter])

        foreach ($attr in $p.Attributes) {
            $attrTypeName = $attr.TypeName.GetReflectionType()
            if ($null -eq $attrTypeName) { continue }

            if ($attrTypeName -eq [System.Management.Automation.ParameterAttribute]) {
                foreach ($na in $attr.NamedArguments) {
                    if ($na.ArgumentName -eq 'Mandatory') {
                        # Bare '[Parameter(Mandatory)]' -> ExpressionOmitted=$true
                        if ($na.ExpressionOmitted) { $isMandatory = $true }
                        elseif ($na.Argument -is [System.Management.Automation.Language.ConstantExpressionAst]) {
                            $isMandatory = [bool]$na.Argument.Value
                        }
                    }
                }
            }
            elseif ($attrTypeName -eq [System.Management.Automation.ValidateSetAttribute]) {
                $values = @()
                foreach ($pa in $attr.PositionalArguments) {
                    if ($pa -is [System.Management.Automation.Language.ConstantExpressionAst]) {
                        $values += [string]$pa.Value
                    }
                }
                if ($values.Count -gt 0) { $schema.enum = $values }
            }
        }

        # Default value (literal only)
        if ($p.DefaultValue -is [System.Management.Automation.Language.ConstantExpressionAst]) {
            $schema.default = $p.DefaultValue.Value
        }

        # Per-parameter description from comment-based help
        $key = $name.ToUpperInvariant()
        if ($paramHelp.ContainsKey($key)) {
            $desc = ($paramHelp[$key] -as [string]).Trim()
            if ($desc) { $schema.description = $desc }
        }

        $properties[$name] = $schema
        if ($isMandatory) { $required.Add($name) | Out-Null }

        $paramMeta[$name] = @{
            IsSwitch    = $isSwitch
            IsMandatory = $isMandatory
            TypeName    = $type.FullName
        }
    }

    $inputSchema = [ordered]@{
        type       = 'object'
        properties = $properties
    }
    # MCP-only override: ProjectRoot is always required from the agent's
    # perspective, because the SF_PROJECT_ROOT env-var fallback used by the
    # scripts only makes sense when invoking them from a shell.
    if ($properties.Contains('ProjectRoot') -and -not $required.Contains('ProjectRoot')) {
        $required.Add('ProjectRoot') | Out-Null
    }
    if ($required.Count -gt 0) { $inputSchema.required = $required.ToArray() }
    $inputSchema.additionalProperties = $false

    $base = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)
    $toolName = ConvertTo-McpKebabName -BaseName $base
    # Strip the standalone-script 'sfs-' prefix from public tool names.
    if ($toolName -like 'sfs-*') { $toolName = $toolName.Substring(4) }

    $toolDescription = if ($synopsis) { $synopsis.Trim() } else { $base }
    if ($description) {
        $toolDescription = "$toolDescription`n`n$($description.Trim())"
    }

    return [ordered]@{
        name        = $toolName
        description = $toolDescription
        inputSchema = $inputSchema
        # Internal-only fields (stripped before sending to clients)
        _scriptPath = $ScriptPath
        _paramMeta  = $paramMeta
    }
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

function Get-SfMcpToolDefinitions {
    <#
    .SYNOPSIS
        Discovers all Sfs-*.ps1 scripts under the standalone scripts folder
        and returns their MCP tool definitions.
    #>
    param(
        [string]$StandaloneRoot = (Join-Path $PSScriptRoot '..\..\scripts\standalone')
    )

    $StandaloneRoot = (Resolve-Path $StandaloneRoot).Path
    $scripts = Get-ChildItem -Path $StandaloneRoot -Filter 'Sfs-*.ps1' -File
    Write-McpLog -Level debug -Message "Discovered $($scripts.Count) standalone script(s) under '$StandaloneRoot'."

    $tools = foreach ($s in $scripts) {
        try {
            Get-McpToolDefinitionFromScript -ScriptPath $s.FullName
        }
        catch {
            Write-McpLog -Level warn -Message "Skipping '$($s.Name)': $($_.Exception.Message)"
        }
    }

    return @($tools)
}

function Get-PublicToolView {
    <#
    .SYNOPSIS
        Returns a copy of the tool definition with internal underscore-prefixed
        fields removed, suitable for sending to MCP clients.
    #>
    param([Parameter(Mandatory)][hashtable]$Tool)
    $public = [ordered]@{}
    foreach ($k in $Tool.Keys) {
        if (-not $k.StartsWith('_')) { $public[$k] = $Tool[$k] }
    }
    return $public
}

function Invoke-SfMcpTool {
    <#
    .SYNOPSIS
        Executes a tool by spawning a child pwsh process running the script
        with the supplied arguments. Returns @{ stdout; stderr; exitCode }.

    .DESCRIPTION
        Stderr from the child wrapper is read line-by-line on a background
        event handler. Lines prefixed with '[progress] ' are forwarded to
        the optional -OnProgress callback (one call per line). All other
        stderr lines are accumulated into the returned 'stderr' string.

        While the child is running, a heartbeat is also dispatched via
        -OnProgress every -HeartbeatSeconds (default 10s) so silent scripts
        still keep the MCP client's per-request timeout alive.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Tool,
        $Arguments,
        [scriptblock]$OnProgress,
        [int]$HeartbeatSeconds = 10
    )

    $scriptPath = $Tool._scriptPath
    $paramMeta  = $Tool._paramMeta

    if ($null -eq $Arguments) { $Arguments = @{} }

    # Convert arguments hashtable / pscustomobject to a hashtable
    if ($Arguments -is [System.Management.Automation.PSCustomObject]) {
        $h = @{}
        foreach ($prop in $Arguments.PSObject.Properties) { $h[$prop.Name] = $prop.Value }
        $Arguments = $h
    }

    # Reject unknown argument names early
    foreach ($k in $Arguments.Keys) {
        if (-not $paramMeta.Contains($k)) {
            throw "Unknown argument '$k' for tool '$($Tool.name)'."
        }
    }

    # Build a typed hashtable of parameters, preserving boolean / numeric
    # types. This will be JSON-encoded and splatted by the wrapper.
    $params = @{}
    foreach ($name in $paramMeta.Keys) {
        if (-not $Arguments.ContainsKey($name)) { continue }
        $value = $Arguments[$name]
        $meta  = $paramMeta[$name]

        if ($meta.IsSwitch) {
            if ([bool]$value) { $params[$name] = $true }
            continue
        }

        if ($null -eq $value) { continue }
        $params[$name] = $value
    }

    $paramsJson = $params | ConvertTo-Json -Depth 10 -Compress
    if ([string]::IsNullOrWhiteSpace($paramsJson)) { $paramsJson = '{}' }

    # Use -File against an in-tree wrapper script so:
    #   - per-tool params bind cleanly via a JSON-encoded hashtable
    #   - errors surface as non-zero exit + stderr (not silent success)
    #   - output is always serialized to a single JSON line
    $wrapperPath = Join-Path $PSScriptRoot 'Invoke-McpToolWrapper.ps1'

    $argList = New-Object System.Collections.Generic.List[string]
    $argList.Add('-NoProfile') | Out-Null
    $argList.Add('-NoLogo') | Out-Null
    $argList.Add('-NonInteractive') | Out-Null
    $argList.Add('-File') | Out-Null
    $argList.Add($wrapperPath) | Out-Null
    $argList.Add('-ScriptPath') | Out-Null
    $argList.Add($scriptPath) | Out-Null
    $argList.Add('-ParamsJson') | Out-Null
    $argList.Add($paramsJson) | Out-Null

    Write-McpLog -Level debug -Message "Invoking tool '$($Tool.name)' -> pwsh $($argList -join ' ')"

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = (Get-Process -Id $PID).Path  # same pwsh that's running the server
    foreach ($a in $argList) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8

    $proc = [System.Diagnostics.Process]::Start($psi)

    # Shared state for the stderr reader. Use a synchronized hashtable so
    # the event handler can safely append from a worker thread.
    $state = [hashtable]::Synchronized(@{
        ProgressQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
        StderrBuf     = New-Object System.Text.StringBuilder
    })

    $eventSub = Register-ObjectEvent -InputObject $proc -EventName 'ErrorDataReceived' -MessageData $state -Action {
        $data = $EventArgs.Data
        if ($null -eq $data) { return }
        $s = $Event.MessageData
        if ($data.StartsWith('[progress] ')) {
            $s.ProgressQueue.Enqueue($data.Substring(11))
        }
        else {
            [void]$s.StderrBuf.AppendLine($data)
        }
    }

    try {
        $proc.BeginErrorReadLine()
        # Stdout is the final JSON payload — read fully in the background.
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()

        $msgRef = [ref]([string]'')
        $heartbeatMs = [Math]::Max(1000, $HeartbeatSeconds * 1000)
        while (-not $proc.WaitForExit($heartbeatMs)) {
            # Drain progress queue first.
            while ($state.ProgressQueue.TryDequeue($msgRef)) {
                if ($OnProgress) {
                    try { & $OnProgress $msgRef.Value } catch {
                        Write-McpLog -Level warn -Message "OnProgress threw: $($_.Exception.Message)"
                    }
                }
            }
            # Then send a heartbeat so silent tools still keep the client alive.
            if ($OnProgress) {
                try { & $OnProgress $null } catch {
                    Write-McpLog -Level warn -Message "OnProgress (heartbeat) threw: $($_.Exception.Message)"
                }
            }
        }

        # Flush any remaining buffered events from the child after exit.
        $proc.WaitForExit()
        # Give the event subscriber a moment to drain the final lines.
        Start-Sleep -Milliseconds 50
        while ($state.ProgressQueue.TryDequeue($msgRef)) {
            if ($OnProgress) {
                try { & $OnProgress $msgRef.Value } catch { }
            }
        }

        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $state.StderrBuf.ToString()
    }
    finally {
        try { $proc.CancelErrorRead() } catch { }
        if ($eventSub) {
            Unregister-Event -SubscriptionId $eventSub.Id -ErrorAction SilentlyContinue
            Remove-Job -Id $eventSub.Id -Force -ErrorAction SilentlyContinue
        }
    }

    return @{
        stdout   = $stdout
        stderr   = $stderr
        exitCode = $proc.ExitCode
    }
}
