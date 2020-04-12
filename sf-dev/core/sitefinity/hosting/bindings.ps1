function sd-bindings-add {
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

function sd-bindings-get {
    [SfProject]$project = sd-project-getCurrent
    if (!$project) {
        throw 'no proj'
    }

    $s = $project.websiteName
    Get-WebBinding -Name $s    
}

function sd-bindings-remove {
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

function sd-bindings-getOrCreateLocalhostBinding {
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$project
    )

    $previous = sd-project-getCurrent
    try {
        $firstNodeBinding = sd-bindings-getLocalhostBinding $project.websiteName
        if (!$firstNodeBinding) {
            $freePort = sd-getFreePort
            sd-project-setCurrent $project
            sd-bindings-add -domain "" -port $freePort
            $firstNodeBinding = sd-bindings-getLocalhostBinding $project.websiteName
        }

        $firstNodeBinding
    }
    finally {
        sd-project-setCurrent $previous
    }
}

function sd-bindings-getLocalhostBinding {
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$websiteName
    )

    iis-bindings-getAll -siteName $websiteName | ? domain -like "" | select -First 1
}

function sd-bindings-getLocalhostUrl {
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$websiteName
    )

    [SiteBinding]$b = sd-bindings-getLocalhostBinding $websiteName
    "$($b.protocol)://localhost:$($b.port)"
}
