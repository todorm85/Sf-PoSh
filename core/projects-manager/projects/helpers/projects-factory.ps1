function new-SfProject {
    [OutputType([SfProject])]
    Param(
        [string]$displayName
    )
    
    $defaultContext = New-Object SfProject -Property @{
        displayName  = $displayName;
        # id           = '';
        # solutionPath = '';
        # webAppPath   = '';
        # websiteName  = '';
    }

    applyConventions $defaultContext

    return $defaultContext
}

function applyConventions {
    Param(
        [SfProject]$context
    )

    $id = _generateId
    $solutionPath = "${projectsDirectory}\${id}";
    $webAppPath = "${projectsDirectory}\${id}\SitefinityWebApp";
    $websiteName = $id

    $context.id = $id
    $context.solutionPath = $solutionPath
    $context.webAppPath = $webAppPath
    $context.websiteName = $websiteName
    $context.containerName = $Script:selectedContainer.name
}
