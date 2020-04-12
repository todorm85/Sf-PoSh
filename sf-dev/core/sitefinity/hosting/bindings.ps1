function s-bindings-add {
    Param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $domain,
        [int]
        $port
    )

    [SfProject]$project = sd-project-getCurrent
    if (!$project) {
        throw 'no proj'
    }

    if (!$port) {
        $port = sd-getFreePort
    }

    New-WebBinding -Name $project.websiteName -IPAddress "*" -Port $port -HostHeader $domain
}

function s-bindings-get {
    [SfProject]$project = sd-project-getCurrent
    if (!$project) {
        throw 'no proj'
    }

    $s = $project.websiteName
    Get-WebBinding -Name $s    
}

function s-bindings-remove {
    Param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $domain,
        [Parameter(Mandatory = $true)]
        [int]
        $port
    )

    [SfProject]$project = sd-project-getCurrent
    if (!$project) {
        throw 'no proj'
    }
    Remove-WebBinding -Name $project.websiteName -HostHeader $domain -Port $port
}

function s-bindings-getOrCreateLocalhostBinding {
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$project
    )

    $previous = sd-project-getCurrent
    try {
        $firstNodeBinding = s-bindings-getLocalhostBinding $project.websiteName
        if (!$firstNodeBinding) {
            $freePort = sd-getFreePort
            sd-project-setCurrent $project
            s-bindings-add -domain "" -port $freePort
            $firstNodeBinding = s-bindings-getLocalhostBinding $project.websiteName
        }

        $firstNodeBinding
    }
    finally {
        sd-project-setCurrent $previous
    }
}

function s-bindings-getLocalhostBinding {
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$websiteName
    )

    iis-bindings-getAll -siteName $websiteName | ? domain -like "" | select -First 1
}

function s-bindings-getLocalhostUrl {
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$websiteName
    )

    [SiteBinding]$b = s-bindings-getLocalhostBinding $websiteName
    "$($b.protocol)://localhost:$($b.port)"
}
