function get-appUrl {
    Param(
        [switch]$useDevUrl,
        [SfProject]$context
    )

    if (!$context) {
        $context = _get-selectedProject
    }
    
    if ($useDevUrl) {
        return get-devAppUrl
    }

    if (-not $context) {
        throw "No project selected."
    }

    $port = @(iis-get-websitePort $context.websiteName)[0]
    if ($port -eq '' -or $null -eq $port) {
        throw "No sitefinity port set."
    }

    $domain = (iis-get-binding -siteName $context.websiteName).domain
    if (-not $domain) {
        $domain = "localhost"
    }
    
    $result = "http://${domain}:$port"
    
    $subAppName = iis-get-subAppName -websiteName $context.websiteName
    if ($null -ne $subAppName) {
        $result = "${result}/${subAppName}"
    }
    
    return $result
}

function generate-domainName ([SfProject]$context) {
    if (-not $context) {        
        $context = _get-selectedProject
    }
    
    return "$($context.displayName)_$($context.id).com"
}

function get-devAppUrl {
    $context = _get-selectedProject
    
    $port = @(iis-get-websitePort $context.websiteName)[0]
    if ($port -eq '' -or $null -eq $port) {
        throw "No sitefinity port set."
    }

    return "http://localhost:${port}"
}