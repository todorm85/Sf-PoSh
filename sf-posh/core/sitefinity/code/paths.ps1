
function _sf-path-getConfigBasePath ([SfProject]$project) {
    if (!$project) {
        $project = sf-project-getCurrent
    }

    "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
}

function _sf-path-getWebConfigPath ([SfProject]$project) {
    if (!$project) {
        $project = sf-project-getCurrent
    }

    "$($project.webAppPath)\web.config"
}

function _sf-path-getSitefinityConfigPath {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $configName
    )

    "$(_sf-path-getConfigBasePath)\$($configName)Config.config"
}