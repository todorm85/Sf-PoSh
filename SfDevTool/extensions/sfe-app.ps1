if ($false) {
    . .\..\sf-all-dependencies.ps1 # needed for intellisense
}

<#
    .SYNOPSIS 
    Generates and adds precompiled templates to selected sitefinity solution.
    .DESCRIPTION
    Precompiled templates give much faster page loads when web app is restarted (when building or rebuilding solution) on first load of the page. Useful with local sitefinity development. WARNING: Any changes to markup are ignored when precompiled templates are added to the project, meaning the markup at the time of precompilation is always used. In order to see new changes to markup you need to remove the precompiled templates and generate them again.
    .OUTPUTS
    None
#>
function sf-add-precompiledTemplates {
    [CmdletBinding()]param()

    $context = _sf-get-context
    $webAppPath = $context.webAppPath

    & $sitefinityCompiler /appdir="${webAppPath}" /username="" /password="" /strategy="Backend" /membershipprovider="Default" /templateStrategy="Default"
}

<#
    .SYNOPSIS 
    Removes the precopiled templates added by sf-add-precompiledTemplates
    .OUTPUTS
    None
#>
function sf-remove-precompiledTemplates {
    [CmdletBinding()]param()

    $context = _sf-get-context
    $webAppPath = $context.webAppPath

    $dlls = Get-ChildItem -Force "${webAppPath}\bin" | Where-Object { ($_.PSIsContainer -eq $false) -and (( $_.Name -like "Telerik.Sitefinity.PrecompiledTemplates.dll") -or ($_.Name -like "Telerik.Sitefinity.PrecompiledPages.Backend.0.dll")) }
    try {
        os-del-filesAndDirsRecursive $dlls
    } catch {
        throw "Item could not be deleted: $dll.PSPath`nMessage:$_.Exception.Message"
    }
}
