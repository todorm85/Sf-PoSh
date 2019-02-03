function get-appUrl {
    Param([switch]$useDevUrl)
    $context = _get-selectedProject

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

function check-domainRegistered ($domain) {
    return Show-Domains -match "^$domain .*"
}

function get-devAppUrl {
    $context = _get-selectedProject
    
    $port = @(iis-get-websitePort $context.websiteName)[0]
    if ($port -eq '' -or $null -eq $port) {
        throw "No sitefinity port set."
    }

    return "http://localhost:${port}"
}