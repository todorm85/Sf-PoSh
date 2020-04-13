$Script:nlbPrefix = "NLB_"
$Script:nlbCertificateParentDomain = "sfdev.com"

function _nlbTags-create {
    "$($Script:nlbPrefix)$([Guid]::NewGuid().ToString().Split('-')[0])"
}

function _nlbTags-getClusterIdFromTag ($tag) {
    $tagParts = $tag.Split('_')
    $tagParts[1]
}

function _nlbTags-getUrlFromTag {
    param (
        $tag
    )
    
    $domain = _nlbTags-getDomain $tag
    "https://$($domain)/"
}

function _nlbTags-filterNlbTag {
    param (
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [string[]]$tags
    )

    $tags | ? { $_.StartsWith($Script:nlbPrefix) }
}

function _nlbTags-getDomain {
    param (
        $tag
    )

    $nlbClusterId = _nlbTags-getClusterIdFromTag $tag
    "$nlbClusterId.$($Script:nlbCertificateParentDomain)"
}