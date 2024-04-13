$Script:projectPropertiesFormatMapping = @(
    # @{  
    #     Name       = "title";
    #     Expression = {
    #         $_.displayName
    #     }
    #     Width = 50
    # },
    # @{
    #     Name       = "branch";
    #     Expression = {
    #         if (!$_.branch) { return }
    #         # "$($_.branchDisplayName) ($($_.daysOld))" 
    #         "$($_.branch)" 
    #     }
    #     Width = 40
    # }
)

function _project-mapProperties {
    param (
        [object[]]$props,
        [switch]$forDisplay,
        [switch]$forSort
    )

    if ($forDisplay) {
        _mapProperties $props {
            param($mp)
            $p = @{
                Expression = $mp.Expression
                Label      = if ($mp.Label) { $mp.Label } else { $mp.Name }
                Width = if ($mp.Width) { $mp.Width } else { 10 }
            }

            $p
        }
    }
    
    if ($forSort) {
        _mapProperties $props {
            param($mp)
            @{
                Expression = $mp.Expression
            }
        }
    }
}

function _mapProperties {
    param(
        [object[]]$props,
        [ScriptBlock]$mappingScript
    )

    foreach ($p in $props) {
        $mp = $Script:projectPropertiesFormatMapping | ? Name -eq $p
        if ($mp) {
            & $mappingScript $mp
        }
        else {
            $p
        }
    }
}
