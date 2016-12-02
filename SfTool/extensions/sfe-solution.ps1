if (-not $sfToolLoaded) {
    . "${PSScriptRoot}\..\sfTool.ps1"
}

function sf-goto-configs {
    $context = _sf-get-context
    $webAppPath = $context.webAppPath

    cd "${webAppPath}\App_Data\Sitefinity\Configurations"
    ls
}

function sf-clear-nugetCache {
    $context = _sf-get-context
    if (!(Test-Path $context.solutionPath)) {
        throw "invalid or no solution path"
    }

    & "$($context.solutionPath)\.nuget\nuget.exe" locals all -clear
}
