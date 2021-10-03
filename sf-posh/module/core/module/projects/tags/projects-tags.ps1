function sf-PSproject-tags-add {
    param (
        [Parameter(ValueFromPipeline)]
        [string]$tagName,
        [Parameter(ValueFromPipeline)]
        [SfProject]$project
    )
    
    process {
        if (!$project -and $tagName) {
            $project = sf-PSproject-get
        }
        
        Run-InFunctionAcceptingProjectFromPipeline {
            _validateTag $tagName
            $project.tags.Add($tagName)
            sf-PSproject-save -context $project
        }
    }
}

Register-ArgumentCompleter -CommandName sf-PSproject-tags-add -ParameterName tagName -ScriptBlock $Script:tagCompleter

function sf-PSproject-tags-remove {
    param (
        [Parameter(ValueFromPipeline)]
        [string]$tagName,
        [Parameter(ValueFromPipeline)]
        [SfProject]$project,
        [switch]$all
    )

    process {
        if (!$project -and $tagName) {
            $project = sf-PSproject-get
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

            sf-PSproject-save -context $project
        } -project $project
    }
}

Register-ArgumentCompleter -CommandName sf-PSproject-tags-remove -ParameterName tagName -ScriptBlock {
    param ( $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )


    $possibleValues = $(sf-PSproject-get).tags
    if ($wordToComplete) {
        $possibleValues = $possibleValues | Where-Object {
            $_ -like "$($wordToComplete.TrimStart($prefixes))*"
        }
    }

    $possibleValues
}

function sf-PSproject-tags-get {
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