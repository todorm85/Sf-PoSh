<#
 Executes the passed script block in the context of the passed project.
 Sets the last argument passed to the script to the $project.
 #>
function Run-InProjectScope {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [Sfproject]$project,
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ScriptBlock]$script,
        [object[]]$scriptArguments
    )
    
    process {
        $previous = sf-project-get -skipValidation
        sf-project-setCurrent $project
        try {
            Invoke-Command -ScriptBlock $script -ArgumentList ($scriptArguments + @($project))
        }
        finally {
            sf-project-setCurrent $previous
        }
    }
}

<#
 Allows the function to be used both in pipeline expressions and as standalone function that takes into account the current selected project.
 Sets the last argument passed to the script to the evaluated $project.
 The calling function must have a parameter named [SfProject]$projectthat is received from the pipeline.
 #>
function Run-InFunctionAcceptingProjectFromPipeline {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ScriptBlock]$script,
        [object[]]$scriptArguments
    )
        
    $isFromPipeline = (Get-PSCallStack)[1].InvocationInfo.ExpectingInput
    [SfProject]$project = (Get-PSCallStack)[1].InvocationInfo.BoundParameters.project
    if (!$project) {
        if ($isFromPipeline) {
            throw "No project received from pipeline!"
        }

        $project = sf-project-get
        Invoke-Command -ScriptBlock $script -ArgumentList ($scriptArguments + @($project))
    }
    else {
        Run-InProjectScope -project $project -script $script -scriptArguments $scriptArguments
        if ($isFromPipeline) {
            $project
        }
    }
}