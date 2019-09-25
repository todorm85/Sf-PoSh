function GetAppUrl {
    Param(
        [switch]$useDevUrl,
        [SfProject]$context
    )

    if (!$context) {
        $context = proj_getCurrent
    }
    
    if ($useDevUrl) {
        return GetDevAppUrl
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

function GenerateDomainName ([SfProject]$context) {
    if (-not $context) {        
        $context = proj_getCurrent
    }
    
    return "$($context.displayName)_$($context.id).com"
}

function GetDevAppUrl {
    $context = proj_getCurrent
    
    $port = @(iis-get-websitePort $context.websiteName)[0]
    if ($port -eq '' -or $null -eq $port) {
        throw "No sitefinity port set."
    }

    return "http://localhost:${port}"
}
