$Script:branchCompleter = {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )
        
    git-completeBranchName $wordToComplete
}
