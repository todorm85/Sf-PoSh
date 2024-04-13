$Script:tagCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )

    # DO NOT USE sf-project-tags-get as it will slow down performance on first load dramatically since it sets each project as current
    $possibleValues = sf-project-get -all | ForEach-Object { $_.tags } | Sort-Object | Get-Unique | Where-Object { $_ }

    if ($wordToComplete) {
        $possibleValues = $possibleValues | Where-Object {
            $_ -like "$($wordToComplete.TrimStart($prefixes))*"
        }
    }

    $possibleValues
}

$Global:SfTagFilterCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    $prefixes = @($excludeTagPrefix, "+")
    $prefix = "$wordToComplete"[0]
    if ($prefix -notin $prefixes) {
        $prefix = ''
    }

    $possibleValues = @(Invoke-Command -ScriptBlock $Script:tagCompleter -ArgumentList $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)


    $possibleValues | % { "$prefix$_" }
}
