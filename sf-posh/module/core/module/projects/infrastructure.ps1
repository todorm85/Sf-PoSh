function Run-InProjectScope {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [Sfproject]$project,
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ScriptBlock]$script
    )
    
    process {
        $previous = sf-project-get -skipValidation
        sf-project-setCurrent $project
        try {
            Invoke-Command -ScriptBlock $script
        }
        finally {
            sf-project-setCurrent $previous
        }
    }
}

function Get-ValidatedSfProjectFromPipelineParameter {
    [OutputType([SfProject])]
    Param (
        [SfProject]$project
    )

    $stack = Get-PSCallStack
    $isFromPipeline = $stack[1].InvocationInfo.ExpectingInput
    if (!$project) {
        if (!$isFromPipeline) {
            sf-project-get
        }
        else {
            throw "No project received from pipeline!"
        }
    }
    else {
        $project
    }
}
