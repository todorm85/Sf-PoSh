function sf-project-tags-add {
    param (
        [Parameter(ValueFromPipeline)]
        [string]$tagName,
        [Parameter(ValueFromPipeline)]
        [SfProject]$project
    )
    
    process {
        if (!$project -and $tagName) {
            $project = sf-project-get
        }
        
        Run-InFunctionAcceptingProjectFromPipeline {
            _validateTag $tagName
            $project.tags.Add($tagName)
            sf-project-save -context $project
        }
    }
}

Register-ArgumentCompleter -CommandName sf-project-tags-add -ParameterName tagName -ScriptBlock $Script:tagCompleter

function sf-project-tags-remove {
    param (
        [Parameter(ValueFromPipeline)]
        [string]$tagName,
        [Parameter(ValueFromPipeline)]
        [SfProject]$project,
        [switch]$all
    )

    process {
        if (!$project -and $tagName) {
            $project = sf-project-get
        }

        Run-InFunctionAcceptingProjectFromPipeline {
            param($project)
            if ($all) {
                $project.tags.Clear() > $null
            }
            else {
                _validateTag $tagName
                if (!$tagName) {
                    throw "Invalid tag name to remove."
                }
                
                if ($project.tags) {
                    $project.tags.Remove($tagName) > $null
                }
            }

            sf-project-save -context $project
        } -project $project
    }
}

Register-ArgumentCompleter -CommandName sf-project-tags-remove -ParameterName tagName -ScriptBlock {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )


    $possibleValues = $(sf-project-get).tags
    if ($wordToComplete) {
        $possibleValues = $possibleValues | Where-Object {
            $_ -like "$($wordToComplete.TrimStart($prefixes))*"
        }
    }

    $possibleValues
}

function sf-project-tags-get {
    param (
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project
    )
    
    process {
        Run-InFunctionAcceptingProjectFromPipeline {
            param($project)
            $all = @()
            $project.tags | % { $all += $_ } # clone of the array or it throws when modified down the pipes
            $all
        }
    }    
}