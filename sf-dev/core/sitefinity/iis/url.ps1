function _get-appUrl {
    Param(
        [switch]$useDevUrl,
        [SfProject]$context
    )

    if (!$context) {
        $context = sf-get-currentProject
    }
    
    if ($useDevUrl) {
        return _get-devAppUrl
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

function _generate-domainName ([SfProject]$context) {
    if (-not $context) {        
        $context = sf-get-currentProject
    }
    
    return "$($context.displayName)_$($context.id).com"
}

function _get-devAppUrl {
    $context = sf-get-currentProject
    
    $port = @(iis-get-websitePort $context.websiteName)[0]
    if ($port -eq '' -or $null -eq $port) {
        throw "No sitefinity port set."
    }

    return "http://localhost:${port}"
}
