if (-not $sfToolLoaded) {
    . "${PSScriptRoot}\..\sfTool.ps1"
}

function sf-add-precompiledTemplates {
    $context = _sf-get-context
    $webAppPath = $context.webAppPath

    & $sitefinityCompiler /appdir="${webAppPath}" /username="" /password="" /strategy="Backend" /membershipprovider="Default" /templateStrategy="Default"
}

function sf-remove-precompiledTemplates {
    $context = _sf-get-context
    $webAppPath = $context.webAppPath

    $dlls = Get-ChildItem -Force "${webAppPath}\bin" | Where-Object { ($_.PSIsContainer -eq $false) -and (( $_.Name -like "Telerik.Sitefinity.PrecompiledTemplates.dll") -or ($_.Name -like "Telerik.Sitefinity.PrecompiledPages.Backend.0.dll")) }
    try {
        os-del-filesAndDirsRecursive $dlls
    } catch {
        throw "Item could not be deleted: $dll.PSPath`nMessage:$_.Exception.Message"
    }
}
