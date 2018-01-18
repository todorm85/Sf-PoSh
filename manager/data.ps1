
function _sfData-get-currentContext {

    _validate-project $script:globalContext
    return $script:globalContext
}

function _sfData-set-currentContext {
    Param($newContext)

    _validate-project $newContext

    $script:globalContext = $newContext
    [System.Console]::Title = $newContext.displayName
}

function _sfData-get-defaultContext {
    Param(
        [string]$displayName,
        [string]$name
        )
        
    function applyContextConventions {
        Param(
            $defaultContext
            )

        $name = $defaultContext.name
        $solutionPath = "${projectsDirectory}\${name}";
        $webAppPath = "${projectsDirectory}\${name}\SitefinityWebApp";
        $websiteName = $name
        $appPool = "DefaultAppPool"

        # initial port to start checking from
        $port = 1111
        while(!(os-test-isPortFree $port) -or !(iis-test-isPortFree $port)) {
            $port++
        }

        $defaultContext.solutionPath = $solutionPath
        $defaultContext.webAppPath = $webAppPath
        $defaultContext.websiteName = $websiteName
        $defaultContext.appPool = $appPool
        $defaultContext.port = $port
    }

    function isNameDuplicate ($name) {
        $sitefinities = @(_sfData-get-allContexts)
        foreach ($sitefinity in $sitefinities) {
            if ($sitefinity.name -eq $name) {
                return $true;
            }
        }    

        return $false;
    }

    function generateName {
        $i = 0;
        while($true) {
            $name = "instance_$i"
            $isDuplicate = (isNameDuplicate $name)
            if (-not $isDuplicate) {
                break;
            }
            
            $i++
        }

        return $name
    }

    function validateName ($context) {
        $name = $context.name
        while ($true) {
            $isDuplicate = (isNameDuplicate $name)
            $isValid = $name -match "^[a-zA-Z]+\w*$"
            if (-not $isValid) {
                Write-Host "Sitefinity name must contain only alphanumerics and not start with number."
                $name = Read-Host "Enter new name: "
            } elseif ($isDuplicate) {
                Write-Host "Duplicate sitefinity naem."
                $name = Read-Host "Enter new name: "
            } else {
                $context.name = $name
                break
            }
        }
    }

    if ([string]::IsNullOrEmpty($name)) {
        $name = generateName    
    }
    
    $defaultContext = @{
        displayName = $displayName;
        name = $name;
        solutionPath = '';
        webAppPath = '';
        dbName = '';
        websiteName = '';
        port = '';
        appPool = '';
    }

    validateName $defaultContext

    applyContextConventions $defaultContext

    return $defaultContext
}

function _sfData-get-allContexts {
    $data = New-Object XML
    $data.Load($script:dataPath)
    return $data.data.sitefinities.sitefinity
}

function _sfData-delete-context {
    Param($context)
    Write-Host "Updating script databse..."
    $name = $context.name
    try {
        $data = New-Object XML
        $data.Load($script:dataPath) > $null
        $sitefinities = $data.data.sitefinities.sitefinity
        ForEach($sitefinity in $sitefinities) {
            if ($sitefinity.name -eq $name) {
                $sitefinitiesParent = $data.SelectSingleNode('/data/sitefinities')
                $sitefinitiesParent.RemoveChild($sitefinity)
            }
        }

        $data.Save($script:dataPath) > $null
    } catch {
        throw "Error deleting sitefinity from ${dataPath}. Message: $_.Exception.Message"
    }
}

function _sfData-init-data {
    # _sfData-set-currentContext $null
    
    if (!(Test-Path $script:dataPath)) {
        Write-Host "Initializing script data..."
        New-Item -ItemType file -Path $script:dataPath

        # Create The Document
        $XmlWriter = New-Object System.XMl.XmlTextWriter($script:dataPath,$Null)

        # Set The Formatting
        $xmlWriter.Formatting = "Indented"
        $xmlWriter.Indentation = "4"

        # Write the XML Decleration
        $xmlWriter.WriteStartDocument()
            $xmlWriter.WriteStartElement("data")
                $xmlWriter.WriteStartElement("sitefinities")
                $xmlWriter.WriteEndElement()
            $xmlWriter.WriteEndElement()
        $xmlWriter.Finalize
        # Finish The Document
        $xmlWriter.Flush()
        $xmlWriter.Close()
    }
}

_sfData-init-data