function _sf-get-context {
    $currentContext = _sfData-get-currentContext
    if ($currentContext -eq '') {
        throw "Invalid context object."
    } elseif ($null -eq $currentContext) {
        throw "No sitefinity selected."
    }

    $context = $currentContext.PsObject.Copy()
    return $context
}

function _sfData-validate-context {
    Param($context)

    if ($context -eq '') {
        throw "Invalid sitefinity context. Cannot be empty string."
    } elseif ($null -ne $context){
        if ($context.name -eq '') {
            throw "Invalid sitefinity context. No sitefinity name."
        }

        if ($context.solutionPath -ne '') {
            if (-not (Test-Path $context.solutionPath)) {
                throw "Invalid sitefinity context. Solution path does not exist."
            }
        }
        
        if (-not(Test-Path $context.webAppPath)) {
            throw "Invalid sitefinity context. No web app path or it does not exist."
        }
    }
}

function _sfData-get-currentContext {

    _sfData-validate-context $script:globalContext
    return $script:globalContext
}

function _sfData-set-currentContext {
    Param($newContext)

    _sfData-validate-context $newContext

    $script:globalContext = $newContext
    [System.Console]::Title = $newContext.displayName
}

function _sfData-apply-contextConventions {
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

function _sfData-get-defaultContext {
    Param(
        [string]$displayName
        )

    function validateName ($name) {
        $sitefinities = @(_sfData-get-allContexts)
        foreach ($sitefinity in $sitefinities) {
            if ($sitefinity.name -eq $name) {
                return $false;
            }
        }    

        return $true;
    }

    function validateDisplayName ($name) {
        $sitefinities = @(_sfData-get-allContexts)
        foreach ($sitefinity in $sitefinities) {
            if ($sitefinity.displayName -eq $name) {
                return $false;
            }
        }    

        return $true;
    }

    $i = 0;
    while($true) {
        $name = "instance_$i"
        $isValid = (validateName $name)
        if ($isValid) {
            break;
        }

        # $i++;
        # $displayName = "${displayName}_${i}"
        $i++
    }

    # set valid display name
    # $i = 0;
    # while($true) {
    #     $isValid = (validateDisplayName $displayName)
    #     if ($isValid) {
    #         break;
    #     }

    #     # $i++;
    #     # $displayName = "${displayName}_${i}"
    #     $displayName = Read-Host -Prompt "Display name $displayName used. Enter new display name: "
    # }

    # build default context object
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

    # check sitefinity name
    while($true) {
        if ($name -notmatch "^[a-zA-Z]+\w*$") {
           Write-Host "Sitefinity name must contain only alphanumerics and not start with number."
           $name = Read-Host "Enter new name: "
        } else {
            $defaultContext.name = $name
            break
        }
    }

    _sfData-apply-contextConventions $defaultContext

    return $defaultContext
}

function _sfData-get-allContexts {
    $data = New-Object XML
    $data.Load($dataPath)
    return $data.data.sitefinities.sitefinity
}

function _sfData-delete-context {
    Param($context)
    Write-Host "Updating script databse..."
    $name = $context.name
    try {
        $data = New-Object XML
        $data.Load($dataPath) > $null
        $sitefinities = $data.data.sitefinities.sitefinity
        ForEach($sitefinity in $sitefinities) {
            if ($sitefinity.name -eq $name) {
                $sitefinitiesParent = $data.SelectSingleNode('/data/sitefinities')
                $sitefinitiesParent.RemoveChild($sitefinity)
            }
        }

        $data.Save($dataPath) > $null
    } catch {
        throw "Error deleting sitefinity from ${dataPath}. Message: $_.Exception.Message"
    }
}

function _sfData-save-context {
    Param($context)

    _sfData-validate-context $context
    try {
        $data = New-Object XML
        $data.Load($dataPath) > $null
        $sitefinities = $data.data.sitefinities.sitefinity
        ForEach($sitefinity in $sitefinities) {
            if ($sitefinity.name -eq $context.name) {
                $sitefinityEntry = $sitefinity
                break
            }
        }

        if ($sitefinityEntry -eq $null) {
            $sitefinityEntry = $data.CreateElement("sitefinity");
            $sitefinities = $data.SelectSingleNode('/data/sitefinities')
            $sitefinities.AppendChild($sitefinityEntry)
        }

        $sitefinityEntry.SetAttribute("name", $context.name)
        $sitefinityEntry.SetAttribute("displayName", $context.displayName)
        $sitefinityEntry.SetAttribute("solutionPath", $context.solutionPath)
        $sitefinityEntry.SetAttribute("webAppPath", $context.webAppPath)
        $sitefinityEntry.SetAttribute("websiteName", $context.websiteName)
        $sitefinityEntry.SetAttribute("branch", $context.branch)
        $sitefinityEntry.SetAttribute("description", $context.description)
        # $sitefinityEntry.SetAttribute("port", $context.port)
        # $sitefinityEntry.SetAttribute("appPool", $context.appPool)

        $data.Save($dataPath) > $null
    } catch {
        throw "Error creating sitefinity in ${dataPath} database file"
    }

    _sfData-set-currentContext $context
}

function _sfData-init-data {
    _sfData-set-currentContext $null
    
    if (!(Test-Path $dataPath)) {
        Write-Host "Initializing script data..."
        New-Item -ItemType file -Path $dataPath

        # Create The Document
        $XmlWriter = New-Object System.XMl.XmlTextWriter($dataPath,$Null)

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