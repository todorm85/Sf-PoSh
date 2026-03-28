function sf-paths-goto {
    param (
        [switch]$logs,
        [switch]$configs,
        [switch]$app,
        [switch]$root
    )

    $p = sf-project-get
    if ($logs) {
        Set-Location -Path "$($p.webAppPath)\App_Data\Sitefinity\Logs"
    }

    if ($configs) {
        Set-Location -Path "$($p.webAppPath)\App_Data\Sitefinity\Configuration"
    }

    if ($app) {
        if (-not (_paths-validatePath $p.webAppPath)) {
            throw "No valid web app path for current project."
        }

        Set-Location -Path "$($p.webAppPath)"
    }

    if ($root) {
        if (_paths-validatePath $p.solutionPath) {
            Set-Location -Path "$($p.solutionPath)"
        } elseif (_paths-validatePath $p.webAppPath) {
            Set-Location -Path "$($p.webAppPath)"
        } else {
            throw "No valid web app path for current project."
        }
    }
}

function _paths-validatePath {
    param (
        $path
    )
    
    return $path -and (Test-Path $path)
}

function RunInRootLocation {
    param (
        $script
    )
    
    $originalLocation = Get-Location
    sf-paths-goto -root
    try {
        Invoke-Command -ScriptBlock $script
    }
    finally {
        Set-Location $originalLocation
    }
}

function RunInLocation {
    param (
        $loc,
        $script
    )

    $originalLocation = Get-Location
    Set-Location $loc
    try {
        Invoke-Command -ScriptBlock $script
    }
    finally {
        Set-Location $originalLocation
    }
}

function _sf-path-getConfigBasePath ([SfProject]$project) {
    if (!$project) {
        $project = sf-project-get
    }

    "$($project.webAppPath)\App_Data\Sitefinity\Configuration"
}

function _sf-path-getWebConfigPath ([SfProject]$project) {
    if (!$project) {
        $project = sf-project-get
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