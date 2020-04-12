function sf-bindings-add {
    Param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $domain,
        [int]
        $port
    )

    [SfProject]$project = sf-project-getCurrent
    if (!$project) {
        throw 'no proj'
    }

    if (!$port) {
        $port = sf-getFreePort
    }

    New-WebBinding -Name $project.websiteName -IPAddress "*" -Port $port -HostHeader $domain
}

function sf-bindings-get {
    [SfProject]$project = sf-project-getCurrent
    if (!$project) {
        throw 'no proj'
    }

    $s = $project.websiteName
    Get-WebBinding -Name $s    
}

function sf-bindings-remove {
    Param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $domain,
        [Parameter(Mandatory = $true)]
        [int]
        $port
    )

    [SfProject]$project = sf-project-getCurrent
    if (!$project) {
        throw 'no proj'
    }
    Remove-WebBinding -Name $project.websiteName -HostHeader $domain -Port $port
}

function sf-bindings-getOrCreateLocalhostBinding {
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$project
    )

    $previous = sf-project-getCurrent
    try {
        $firstNodeBinding = sf-bindings-getLocalhostBinding $project.websiteName
        if (!$firstNodeBinding) {
            $freePort = sf-getFreePort
            sf-project-setCurrent $project
            sf-bindings-add -domain "" -port $freePort
            $firstNodeBinding = sf-bindings-getLocalhostBinding $project.websiteName
        }

        $firstNodeBinding
    }
    finally {
        sf-project-setCurrent $previous
    }
}

function sf-bindings-getLocalhostBinding {
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$websiteName
    )

    iis-bindings-getAll -siteName $websiteName | ? domain -like "" | select -First 1
}

function sf-bindings-getLocalhostUrl {
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$websiteName
    )

    [SiteBinding]$b = sf-bindings-getLocalhostBinding $websiteName
    "$($b.protocol)://localhost:$($b.port)"
}
