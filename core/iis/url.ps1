function _sf-get-appUrl {
    Param([switch]$useDevUrl)
    $context = _get-selectedProject

    if ($useDevUrl) {
        return _sf-get-devAppUrl
    }

    $port = @(iis-get-websitePort $context.websiteName)[0]
    if ($port -eq '' -or $null -eq $port) {
        throw "No sitefinity port set."
    }

    $domain = _sf-get-domain
    $result = "http://${domain}:$port"
    if ($null -ne $subAppName) {
        $result = "${result}/${subAppName}"
    }

    return $result
}

function _sf-new-domain ($displayName) {
    $result = "$($context.displayName).com"
    return $result    
}

function _sf-get-domain {
    $proj = _get-selectedProject
    return "$($proj.displayName)-$($proj.name).com"
}

function _sf-check-domainRegistered ($domain) {
    return Show-Domains -match "^$domain .*"
}

function _sf-get-devAppUrl {
    $context = _get-selectedProject
    
    $port = @(iis-get-websitePort $context.websiteName)[0]
    if ($port -eq '' -or $null -eq $port) {
        throw "No sitefinity port set."
    }

    return "http://localhost:${port}"
}