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
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Tool,
        $Arguments
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

    # Build the trailing script arguments (passed via $args inside the wrapper).
    $scriptArgs = New-Object System.Collections.Generic.List[string]
    foreach ($name in $paramMeta.Keys) {
        if (-not $Arguments.ContainsKey($name)) { continue }
        $value = $Arguments[$name]
        $meta  = $paramMeta[$name]

        if ($meta.IsSwitch) {
            if ([bool]$value) { $scriptArgs.Add("-$name") | Out-Null }
            continue
        }

        if ($null -eq $value) { continue }
        $scriptArgs.Add("-$name") | Out-Null
        $scriptArgs.Add([string]$value) | Out-Null
    }

    # Wrap the script call so its [pscustomobject] output is serialized to
    # compact JSON on stdout (a single line is fine; we surface stdout as-is).
    $escapedPath = $scriptPath -replace "'", "''"
    $wrapper = "& { `$o = & '$escapedPath' @args; if (`$null -ne `$o) { `$o | ConvertTo-Json -Depth 10 -Compress } }"

    $argList = New-Object System.Collections.Generic.List[string]
    $argList.Add('-NoProfile') | Out-Null
    $argList.Add('-NoLogo') | Out-Null
    $argList.Add('-NonInteractive') | Out-Null
    $argList.Add('-Command') | Out-Null
    $argList.Add($wrapper) | Out-Null
    if ($scriptArgs.Count -gt 0) {
        # '--' separates pwsh's own args from the remaining args that become $args
        $argList.Add('--') | Out-Null
        foreach ($a in $scriptArgs) { $argList.Add($a) | Out-Null }
    }

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

    # Read both streams concurrently to avoid deadlock on large output.
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    $proc.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()

    return @{
        stdout   = $stdout
        stderr   = $stderr
        exitCode = $proc.ExitCode
    }
}
