function new-SfProject {
    [OutputType([SfProject])]
    Param(
        [string]$displayName,
        [string]$id
    )
    
    $defaultContext = New-Object SfProject -Property @{
        displayName  = $displayName;
        id           = $id;
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

    if (-not $context.id) {
        $context.id = _generateId
    }

    $id = $context.id

    $solutionPath = "${projectsDirectory}\${id}";
    $webAppPath = "${projectsDirectory}\${id}\SitefinityWebApp";
    $websiteName = $id

    $context.solutionPath = $solutionPath
    $context.webAppPath = $webAppPath
    $context.websiteName = $websiteName
    $context.containerName = $Script:selectedContainer.name
}
