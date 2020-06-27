$Script:tagCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )


    $possibleValues = sf-tags-getAllAvailable
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
