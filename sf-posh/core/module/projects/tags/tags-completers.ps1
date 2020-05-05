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

Register-ArgumentCompleter -CommandName sf-tags-add -ParameterName tagName -ScriptBlock $tagCompleter

Register-ArgumentCompleter -CommandName sf-tags-remove -ParameterName tagName -ScriptBlock {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )


    $possibleValues = $(sf-project-getCurrent).tags
    if ($wordToComplete) {
        $possibleValues = $possibleValues | Where-Object {
            $_ -like "$($wordToComplete.TrimStart($prefixes))*"
        }
    }

    $possibleValues
}

$Script:tagFilterCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    $prefixes = @($excludeTagPrefix)
    $prefix = "$wordToComplete"[0]
    if ($prefix -notin $prefixes) {
        $prefix = ''
    }

    $possibleValues = @(Invoke-Command -ScriptBlock $Script:tagCompleter -ArgumentList $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)


    $possibleValues | % { "$prefix$_" }
}

$Script:selectFunctionTagCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )

    $values = @(Invoke-Command -ScriptBlock $tagFilterCompleter -ArgumentList $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $values += @("+a")
    $values += @("+u")
    $values
}

Register-ArgumentCompleter -CommandName sf-project-select -ParameterName tagsFilter -ScriptBlock $selectFunctionTagCompleter

Register-ArgumentCompleter -CommandName sf-tags-addToDefaultFilter -ParameterName tag -ScriptBlock $Script:tagFilterCompleter

Register-ArgumentCompleter -CommandName sf-tags-removeFromDefaultFilter -ParameterName tag -ScriptBlock $Script:tagFilterCompleter
