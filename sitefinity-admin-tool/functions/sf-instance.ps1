function sf-create-sitefinity {
    Param(
        [string]$name,
        [string]$branch = "$/CMS/Sitefinity 4.0/Code Base",
        [switch]$startWebApp,
        [switch]$buildSolution
        )

    $defaultContext = _sfData-get-defaultContext $name
    try {
        $newContext = @{ name = $defaultContext.name }
        $newContext.displayName = $defaultContext.displayName
        if (Test-Path $defaultContext.solutionPath) {
            throw "Path already exists:" + $defaultContext.solutionPath
        }

        Write-Host "Creating solution path..."
        New-Item $defaultContext.solutionPath -type directory > $null
        $newContext.solutionPath = $defaultContext.solutionPath;

        # create and map workspace
        Write-Host "Creating workspace..."
        $workspaceName = $defaultContext.displayName
        tfs-create-workspace $workspaceName $defaultContext.solutionPath

        Write-Host "Creating workspace mappings..."
        tfs-create-mappings -branch $branch -branchMapPath $defaultContext.solutionPath -workspaceName $workspaceName

        Write-Host "Getting latest workspace changes..."
        tfs-get-latestChanges -branchMapPath $defaultContext.solutionPath

        # persist current context to script data
        $newContext.dbName = $defaultContext.dbName
        $newContext.webAppPath = $defaultContext.solutionPath + '\SitefinityWebApp'
        $oldContext = ''
        $oldContext = _sfData-get-currentContext
        _sfData-set-currentContext $newContext
        _sfData-save-context $newContext
    } catch {
        Write-Host "############ CLEANING UP ############"
        Set-Location $PSScriptRoot
        if ($newContext.solutionPath -ne '' -and $newContext.solutionPath -ne $null) {
            Remove-Item -Path $newContext.solutionPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            if ($ProcessError) {
                Write-Host $ProcessError
            }
        }

        if ($oldContext -ne '') {
            _sfData-set-currentContext $oldContext
        }

        throw "Nothing created. Try again. Error: $_.Exception.Message"
    }

    try {
        if ($buildSolution) {
            Write-Host "Building solution..."
            sf-build-solution
        }
    } catch {
        $startWebApp = $false
        Write-Warning "SOLUTION WAS NOT BUILT. Message: $_.Exception.Message"
    }

    try {
        Write-Host "Creating website..."
        _sf-create-website -newWebsiteName $defaultContext.websiteName -newPort $defaultContext.port -newAppPool $defaultContext.appPool
    } catch {
        $startWebApp = $false
        Write-Warning "WEBSITE WAS NOT CREATED. Message: $_.Exception.Message"
    }

    if ($startWebApp) {
        try {
            Write-Host "Initializing Sitefinity"
            _sf-create-startupConfig
            _sf-start-sitefinity
        } catch {
            Write-Warning "APP WAS NOT INITIALIZED. $_.Exception.Message"
            _sf-delete-startupConfig
        }
    }

    # Display message
    os-popup-notification "Operation completed!"
}

function sf-import-sitefinity {
    Param(
        [Parameter(Mandatory=$true)][string]$displayName,
        [Parameter(Mandatory=$true)][string]$path
        )

    if (!(Test-Path $path)) {
        throw "Invalid path"
    }

    $isSolution = Test-Path "$path\Telerik.Sitefinity.sln"
    $isWebApp = Test-Path "$path\web.config"
    if (-not $isWebApp -and -not $isSolution) {
        throw "No web app or solution found."
    }

    if ($isWebApp -and $isSolution) {
        throw "Cannot determine whether webapp or solution."
    }

    $defaultContext = _sfData-get-defaultContext $displayName
    $newContext = @{ name = $defaultContext.name }
    $newContext.displayName = $defaultContext.displayName
    if ($isSolution) {
        $newContext.solutionPath = $path
        $newContext.webAppPath = $path + '\SitefinityWebApp'
    } else {
        $newContext.solutionPath = ''
        $newContext.webAppPath = $path
    }

    while ($appInitialized -ne 'y' -and $appInitialized -ne 'n') {
        $appInitialized = Read-Host -Prompt 'Is your app initialized with a database? [y/n]'
    }

    if ($appInitialized -eq 'y') {
        $isDuplicate = $false
        while (!$isDuplicate) {
            $dbName = Read-Host -Prompt 'Enter database name: '
            $isDuplicate = sql-test-isDbNameDuplicate $dbName
        }

        $newContext.dbName = $dbName
    } else {
        $newContext.dbName = $defaultContext.dbName
    }

    while ($hasWebSite -ne 'y' -and $hasWebSite -ne 'n') {
        $hasWebSite = Read-Host -Prompt 'Does your app has a website created for it? [y/n]'
    }

    if ($hasWebSite -eq 'y') {
        $isDuplicate = $false
        while (!$isDuplicate) {
            $websiteName = Read-Host -Prompt 'Enter website name: '
            $isDuplicate = sql-test-isDbNameDuplicate $dbName
            $newContext.websiteName = $websiteName
        }
    } else {
        try {
            Write-Host "Creating website..."
            _sfData-set-currentContext $newContext
            _sf-create-website -newWebsiteName $defaultContext.websiteName -newPort $defaultContext.port -newAppPool $defaultContext.appPool
        } catch {
            $startWebApp = $false
            Write-Warning "WEBSITE WAS NOT CREATED. Message: $_.Exception.Message"
        }
    }

    _sfData-set-currentContext $newContext
    _sfData-save-context $newContext

    # Display message
    os-popup-notification "Operation completed!"
}

function sf-delete-sitefinity {
    Param(
        [switch]$keepWorkspace,
        [switch]$keepProjectFiles
        )
    $context = _sf-get-context
    $solutionPath = $context.solutionPath
    $workspaceName = tfs-get-workspaceName $context.webAppPath
    $dbName = $context.dbName
    $websiteName = $context.websiteName

    # while ($true) {
    #     $isConfirmed = Read-Host -Prompt "WARNING! Current operation will reset IIS. You also need to have closed the current sitefinity solution in Visual Studio and any opened browsers for complete deletion. Continue [y/n]?"
    #     if ($isConfirmed -eq 'y') {
    #         break;
    #     }

    #     if ($isConfirmed -eq 'n') {
    #         return
    #     }
    # }

    Set-Location -Path $PSScriptRoot

    # Del workspace
    if ($workspaceName -ne '' -and !($keepWorkspace)) {
        Write-Host "Deleting workspace..."
        try {
            tfs-delete-workspace $workspaceName
        } catch {
            Write-Host "Could not delete workspace $_.Exception.Message"
        }
    }

    # Del db
    Write-Host "Deleting sitefinity database..."
    if ($dbName -ne '') {
        try {
            sql-delete-database -dbName $dbName
        } catch {
            Write-Host "Could not delete database: ${dbName}. $_.Exception.Message"
        }
    }

    # Del Website
    Write-Host "Deleting website..."
    if ($websiteName -ne '') {
        try {
            _sf-delete-website
        } catch {
            Write-Host "Could not delete website ${websiteName}. $_.Exception.Message"
        }
    }

    # Del dir
    if (!($keepProjectFiles)) {
        Write-Host "Resetting IIS and deleting solution directory..."
        try {
            iisreset.exe > $null
            if ($solutionPath -ne "") {
                Remove-Item $solutionPath -recurse -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            } else {
                Remove-Item $context.webAppPath -recurse -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            }

            if ($ProcessError) {
                throw $ProcessError
            }
        } catch {
            Write-Host "Errors deleting sitefinity directory. $_.Exception.Message"
        }
    }

    Write-Host "Deleting data entry..."
    _sfData-delete-context $context
    _sfData-set-currentContext $null

    # Display message
    os-popup-notification -msg "Operation completed!"

    sf-select-sitefinity
}

function sf-select-sitefinity {
    $sitefinities = @(_sfData-get-allContexts)

    sf-show-allSitefinities

    while ($true) {
        [int]$choice = Read-Host -Prompt 'Choose sitefinity'
        $selectedSitefinity = $sitefinities[$choice]
        if ($selectedSitefinity -ne $null) {
            break;
        }
    }

    _sfData-set-currentContext $selectedSitefinity
    Set-Location $selectedSitefinity.webAppPath
}

function sf-rename-sitefinity {
    Param([string]$newName)

    $context = _sf-get-context

    if ([string]::IsNullOrEmpty($newName)) {
        $newName = $context.name
    }

    $context.displayName = $newName
    $workspaceName = tfs-get-workspaceName $context.webAppPath
    if ($workspaceName -ne "") {
        & $tfPath workspace /newname:$newName $workspaceName /noprompt
        $workspaceName = $newName
    }
    
    _sfData-save-context $context
}

function sf-show-selectedSitefinity {
    $context = _sf-get-context

    $ports = @(iis-get-websitePort $context.websiteName)
    $appPool = @(iis-get-siteAppPool $context.websiteName)
    $workspaceName = tfs-get-workspaceName $context.webAppPath
    $mapping = tfs-get-mappings $context.webAppPath

    $sitefinity = @(
        [pscustomobject]@{id = 1; Parameter = "Sitefinity name"; Value = $context.displayName;},
        [pscustomobject]@{id = 2; Parameter = "Solution path"; Value = $context.solutionPath;},
        [pscustomobject]@{id = 3; Parameter = "Web app path"; Value = $context.webAppPath;},
        [pscustomobject]@{id = 4; Parameter = "Workspace name"; Value = $workspaceName;},
        [pscustomobject]@{id = 5; Parameter = "Mapping"; Value = $mapping;},
        [pscustomobject]@{id = 6; Parameter = "Database Name"; Value = $context.dbName;},
        [pscustomobject]@{id = 7; Parameter = "Website Name in IIS"; Value = $context.websiteName;},
        [pscustomobject]@{id = 8; Parameter = "Ports"; Value = $ports;},
        [pscustomobject]@{id = 9; Parameter = "Application Pool Name"; Value = $appPool;}
    )

    $sitefinity | Sort-Object -Property id | Format-Table -Property Parameter, Value -auto
}

function sf-show-allSitefinities {
    $sitefinities = @(_sfData-get-allContexts)
    if ($sitefinities[0] -eq $null) {
        Write-Host "No sitefinities! Create one first. sf-create-sitefinity or manually add in sf-data.xml"
        return
    }
    
    [System.Collections.ArrayList]$output = @()
    foreach ($sitefinity in $sitefinities) {
        $ports = @(iis-get-websitePort $sitefinity.websiteName)
        $mapping = tfs-get-mappings $sitefinity.webAppPath
        if ($mapping) {
            $mapping = $mapping.split("4.0")[3]
        }

        $index = [array]::IndexOf($sitefinities, $sitefinity)

        $output.add([pscustomobject]@{id = $index; Title = "$index : $($sitefinity.displayName)"; Branch = "$mapping"; Ports = "$ports";}) > $null
    }

    $output | Sort-Object -Property id | Format-Table -Property Title, Branch, Ports -auto
}
