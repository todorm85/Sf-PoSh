function sf-tags-getAllAvailable {
    sf-project-get -all | ForEach-Object { $_.tags } | Sort-Object | Get-Unique | Where-Object { $_ }
}

function sf-tags-add {
    param (
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project,
        [string]$tagName
    )
    
    process {
        RunWithValidatedProject {
            _validateTag $tagName
            $project.tags.Add($tagName)
            sf-project-save -context $project
        }
    }
}

Register-ArgumentCompleter -CommandName sf-tags-add -ParameterName tagName -ScriptBlock $Script:tagCompleter

function sf-tags-remove {
    param (
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project,
        [string]$tagName,
        [switch]$all
    )

    process {
        RunWithValidatedProject {
            if ($all) {
                $project.tags.Clear()
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
        }
    }
}

Register-ArgumentCompleter -CommandName sf-tags-remove -ParameterName tagName -ScriptBlock {
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

function sf-tags-get {
    $project = sf-project-get
    return $project.tags
}
