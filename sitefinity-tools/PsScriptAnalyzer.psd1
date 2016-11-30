# https://github.com/PowerShell/PSScriptAnalyzer/tree/development/RuleDocumentation

@{
    Severity=@('Error','Warning')
    ExcludeRules=@(
                'PSAvoidUsingCmdletAliases',
                'PSAvoidUsingWriteHost',
                'PSUseApprovedVerbs')
}