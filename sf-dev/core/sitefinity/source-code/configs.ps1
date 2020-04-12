function sf-appStartupConfig-remove {
    $context = sf-project-getCurrent
    $configPath = "$($context.webAppPath)\App_Data\Sitefinity\Configuration\StartupConfig.config"
    Remove-Item -Path $configPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
    if ($ProcessError) {
        throw $ProcessError
    }
}

function sf-appStartupConfig-create {
    param(
        [string]$user = $GLOBAL:sf.Config.sitefinityUser,
        [Parameter(Mandatory = $true)][string]$dbName,
        [string]$password = $GLOBAL:sf.Config.sitefinityPassword,
        [string]$sqlUser = $GLOBAL:sf.Config.sqlUser,
        [string]$sqlPass = $GLOBAL:sf.Config.sqlPass
    )

    $context = sf-project-getCurrent
    $webAppPath = $context.webAppPath

    Write-Information "Creating StartupConfig..."
    try {
        $appConfigPath = "${webAppPath}\App_Data\Sitefinity\Configuration"
        if (-not (Test-Path $appConfigPath)) {
            New-Item $appConfigPath -type directory > $null
        }

        $configPath = "${appConfigPath}\StartupConfig.config"

        if (Test-Path -Path $configPath) {
            Remove-Item $configPath -force -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            if ($ProcessError) {
                throw "Could not remove old StartupConfig $ProcessError"
            }
        }

        if ((sql-test-isDbNameDuplicate -dbName $dbName) -or [string]::IsNullOrEmpty($dbName)) {
            throw "Error creating startup.config. Database with name $dbName already exists."
        }

        $username = $user.split('@')[0]

        $XmlWriter = New-Object System.XMl.XmlTextWriter($configPath, $Null)
        $xmlWriter.WriteStartDocument()
        $xmlWriter.WriteStartElement("startupConfig")
        $XmlWriter.WriteAttributeString("username", $user)
        $XmlWriter.WriteAttributeString("password", $password)
        $XmlWriter.WriteAttributeString("enabled", "True")
        $XmlWriter.WriteAttributeString("initialized", "False")
        $XmlWriter.WriteAttributeString("email", $user)
        $XmlWriter.WriteAttributeString("firstName", $username)
        $XmlWriter.WriteAttributeString("lastName", $username)
        $XmlWriter.WriteAttributeString("dbName", $dbName)
        $XmlWriter.WriteAttributeString("dbType", "SqlServer")
        $XmlWriter.WriteAttributeString("sqlInstance", $GLOBAL:sf.config.sqlServerInstance)
        $XmlWriter.WriteAttributeString("sqlAuthUserName", $sqlUser)
        $XmlWriter.WriteAttributeString("sqlAuthUserPassword", $sqlPass)
        $xmlWriter.WriteEndElement()
        $xmlWriter.Finalize
        $xmlWriter.Flush()
        $xmlWriter.Close() > $null
    }
    catch {
        throw "Error creating startupConfig. Message: $_"
    }
}
