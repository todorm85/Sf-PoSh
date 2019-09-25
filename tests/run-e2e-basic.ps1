Invoke-Pester "$PSScriptRoot\e2e" -ExcludeTag ('create-tfs', 'delete')
