function sd-iisSite-getUrl {
    Param(
        [switch]$useDevUrl
    )

    $context = sd-project-getCurrent
    
    if (!$context) {
        throw "No project selected."
    }

    if ($useDevUrl) {
        return _getDevAppUrl
    }

    $port = @(sd-iisSite-getDefaultPort)[0]
    if ($port -eq '' -or $null -eq $port) {
        throw "No sitefinity port set."
    }

    $binding = sd-iisSite-getDefaultBinding
    $domain = if ($binding) {$binding.domain} else { $null }
    if (-not $domain) {
        $domain = "localhost"
    }
    
    $result = "http://${domain}:$port"
    
    $subAppName = sd-iisSite-getSubAppName -websiteName $context.websiteName
    if ($null -ne $subAppName) {
        $result = "${result}/${subAppName}"
    }
    
    return $result
}

function _generateDomainName {
    Param(
        [Parameter(Mandatory=$true)]
        [SfProject]
        $context
    )
    
    return "$($context.displayName)_$($context.id).com"
}

function _getDevAppUrl {
    $context = sd-project-getCurrent
    
    $port = @(sd-iisSite-getDefaultPort $context.websiteName)[0]
    if ($port -eq '' -or $null -eq $port) {
        throw "No sitefinity port set."
    }

    return "http://localhost:${port}"
}
