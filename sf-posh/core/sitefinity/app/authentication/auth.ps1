function sf-auth-ldap {
    Param(
        [switch]$enable,
        [switch]$disable
    )

    $config = sf-config-open -name "Security"
    $root = $config["securityConfig"]
    if ($enable) {
        $ldapConnection = Xml-GetOrCreateElementPath $root -elementPath "LdapConnections/connections/LdapConnection[@name=DefaultLdapConnection]"
        $ldapConnection.SetAttribute("serverName", "ntsofpdcdev01.dev.progress.com")
        $ldapConnection.SetAttribute("connectionDomain", "dev.progress.com")
        $ldapConnection.SetAttribute("connectionUsername", "sfldapuser")
        $ldapConnection.SetAttribute("connectionPassword", "RqzWtboY0AsCctlz")
        $ldapConnection.SetAttribute("usersDN", "OU=Sitefinity,OU=PSC Service Accounts,DC=dev,DC=progress,DC=com")
        $ldapConnection.SetAttribute("rolesDns", "dc=bedford,dc=progress,dc=com")

        $ldapUsers = xml-getOrCreateElementPath $root -elementPath "membershipProviders/add[@name=LdapUsers]"
        $ldapUsers.SetAttribute("enabled", "True")

        $roleProvider = xml-getOrCreateElementPath $root -elementPath "roleProviders/add[@name=LdapRoles]"
        $roleProvider.SetAttribute("enabled", "True")

        $administrativeRoles = xml-getOrCreateElementPath $root -elementPath "administrativeRoles/role[@roleName=SitefinityToolingTeam]"
        $administrativeRoles.SetAttribute("roleProvider", "LdapRoles")
        Write-Host "User: ldapadmin, Pass: P@ssw0rd4321"
    }

    if ($disable) {
        $ldapUsers = xml-getOrCreateElementPath $root -elementPath "membershipProviders/add[@name=LdapUsers]"
        $ldapUsers.SetAttribute("enabled", "False")

        $roleProvider = xml-getOrCreateElementPath $root -elementPath "roleProviders/add[@name=LdapRoles]"
        $roleProvider.SetAttribute("enabled", "False")
    }

    sf-config-save -config $config
}

function sf-auth-azureB2C {
    param (
        [switch]$enable,
        [switch]$disable
    )

    $config = sf-config-open -name "Authentication"
    $root = $config["authenticationConfig"]

    if ($enable) {
        $provider = xml-getOrCreateElementPath $root -elementPath "securityTokenServiceSettings/authenticationProviders/add[@name=OpenIDConnect]"
        $provider.SetAttribute("clientId", "a6378a5c-e146-44d8-9fa3-b52bea7eecd4")
        $provider.SetAttribute("scope", "openid profile email")
        $provider.SetAttribute("authority", "https://login.microsoftonline.com/sitefinityunit3.onmicrosoft.com/v2.0/authorize")
        $provider.SetAttribute("metadataAddress", "https://login.microsoftonline.com/sitefinityunit3.onmicrosoft.com/v2.0/.well-known/openid-configuration")
        $provider.SetAttribute("redirectUri", "https://sitefinitylocal.com:417/Sitefinity/Authenticate/OpenID/signin-custom")
        $provider.SetAttribute("postLogoutRedirectUri", "https://sitefinitylocal.com:417/")
        $provider.SetAttribute("enabled", "True")
        $provider.SetAttribute("autoAssignedRoles", "Editors")
        $provider.SetAttribute("requireEmail", "False")
        $provider.SetAttribute("autoAssignedRoles", "Users, BackendUsers, Administrators")
        $provider.SetAttribute("config:flags", "1")
        Write-Warning "You must login with the user account sitefinity_test@sitefinityunit3.onmicrosoft.com k3ZgwBCP3 and use https://sitefinitylocal.com:417 as domain"
    }
    
    if ($disable) {
        $provider = xml-getOrCreateElementPath $root -elementPath "securityTokenServiceSettings/authenticationProviders/add[@name=OpenIDConnect]"
        $provider.SetAttribute("enabled", "False")
    }

    sf-config-save -config $config
}

function sf-auth-facebook {
    param (
        [switch]$enable,
        [switch]$disable
    )

    $config = sf-config-open -name "Authentication"
    $root = $config["authenticationConfig"]

    if ($enable) {
        $provider = xml-getOrCreateElementPath $root -elementPath "securityTokenServiceSettings/authenticationProviders/add[@name=Facebook]"
        $provider.SetAttribute("appId", "1939601666302240")
        $provider.SetAttribute("appSecret", "4d4a8a2585baf51d4f9db79e6af4bee0")
        $provider.SetAttribute("enabled", "True")
        $provider.SetAttribute("autoAssignedRoles", "Users, BackendUsers, Administrators")
        $provider.SetAttribute("config:flags", "1")
        Write-Warning "You must login with the user account sitefinity_afcrrkq_testuser@tfbnw.net z2KgBW3CPTOmg34LDjy and use https://sitefinitylocal.com:417 as domain"
    }
    
    if ($disable) {
        $provider = xml-getOrCreateElementPath $root -elementPath "securityTokenServiceSettings/authenticationProviders/add[@name=Facebook]"
        $provider.SetAttribute("enabled", "False")
    }

    sf-config-save -config $config
}

function sf-auth-aspsql {
    param (
        [switch]$enable,
        [switch]$disable
    )
    
    $config = sf-config-open -name "web"
    $root = $config["configuration"]
    $password = ConvertTo-SecureString "admin@2admin@2" -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential("sa", $password)
    $p = sf-project-get
    $dbName = $p.id + "_aspMembership"
    if ($enable) {
        $RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile("Sitefinity", "c:\$dbName.mdf")
        $RelocateLog = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile("Sitefinity_Log", "c:\$dbName.ldf")
        Restore-SqlDatabase -ServerInstance "." -Database $dbName -BackupFile "$PSScriptRoot\Sitefinity.bak" -Credential $credential -ReplaceDatabase -RelocateFile @($RelocateData, $RelocateLog)

        $connectionString = xml-getOrCreateElementPath $root -elementPath "connectionStrings/add[@name=AspNetMembership]"
        $connectionString.SetAttribute("connectionString", "data source=.;UID=sa;PWD=admin@2admin@2;initial catalog=$dbName")

        $roleManager = xml-getOrCreateElementPath $root -elementPath "system.web/roleManager"
        $roleManager.SetAttribute("enabled", "true")

        $roleProvider = xml-getOrCreateElementPath $roleManager -elementPath "providers/clear"
        $roleProvider = xml-getOrCreateElementPath $roleManager -elementPath "providers/add[@name=AspNetSqlRoleProvider]"
        $roleProvider.SetAttribute("connectionStringName", "AspNetMembership")
        $roleProvider.SetAttribute("applicationName", "/")
        $roleProvider.SetAttribute("type", "System.Web.Security.SqlRoleProvider")

        $membershipProvider = xml-getOrCreateElementPath $root "system.web/membership/providers/add[@name=AspNetSqlMembershipProvider]"
        $membershipProvider.SetAttribute("connectionStringName", "AspNetMembership")
        $membershipProvider.SetAttribute("enablePasswordRetrieval", "false")
        $membershipProvider.SetAttribute("enablePasswordReset", "true")
        $membershipProvider.SetAttribute("requiresQuestionAndAnswer", "false")
        $membershipProvider.SetAttribute("requiresUniqueEmail", "false")
        $membershipProvider.SetAttribute("maxInvalidPasswordAttempts", "5")
        $membershipProvider.SetAttribute("minRequiredPasswordLength", "6")
        $membershipProvider.SetAttribute("minRequiredNonalphanumericCharacters", "0")
        $membershipProvider.SetAttribute("passwordAttemptWindow", "11")
        $membershipProvider.SetAttribute("applicationName", "/")
        $membershipProvider.SetAttribute("type", "System.Web.Security.SqlMembershipProvider")
    }

    if ($disable) {
        sql-delete-database -dbName $dbName

        xml-removeElementIfExists $root "connectionStrings/add[@name='AspNetMembership']"
        
        xml-removeElementIfExists $root "system.web/roleManager"

        xml-removeElementIfExists $root "system.web/membership/providers/add[@name='AspNetSqlMembershipProvider']"
    }

    sf-config-save -config $config
}

# Use localhost:18001
function sf-auth-google {
    param (
        [switch]$enable,
        [switch]$disable
    )

    $config = sf-config-open -name "Authentication"
    $root = $config["authenticationConfig"]

    if ($enable) {
        $googleEntry = xml-getOrCreateElementPath $root -elementPath "securityTokenServiceSettings/authenticationProviders/add[@name=Google]"
        $googleEntry.SetAttribute("appId", "771822853545-92c5hongqfb80nh927ejv6hajpceorbs.apps.googleusercontent.com")
        $googleEntry.SetAttribute("appSecret", "Sn8tDo28EIAL-oVxOy9euYp0")
        $googleEntry.SetAttribute("enabled", "True")
        $googleEntry.SetAttribute("autoAssignedRoles", "Users, BackendUsers, Administrators")
        $googleEntry.SetAttribute("config:flags", "1")
    }
    
    if ($disable) {
        $googleEntry = xml-getOrCreateElementPath $root -elementPath "securityTokenServiceSettings/authenticationProviders/add[@name=Google]"
        $googleEntry.SetAttribute("enabled", "False")
    }

    sf-config-save -config $config
}

function sf-auth-basic {
    param (
        [switch]$disable
    )

    $configVal = "True"
    if ($disable) {
        $configVal = "False"
    }

    $config = sf-config-open -name "Authentication"
    $root = $config["authenticationConfig"]
    $relyingPartySettings = xml-getOrCreateElementPath -elementPath "relyingPartySettings" -root $root
    $existingValue = $relyingPartySettings.GetAttribute("enableBasicAuthenticationForBackendServices")
    if (!$existingValue -or ($existingValue.ToLower() -ne $configVal.ToLower())) {
        $relyingPartySettings.SetAttribute("enableBasicAuthenticationForBackendServices", $configVal)
        sf-config-save -config $config
        sf-iis-appPool-Reset
        sf-app-ensureRunning
        if (!$disable) {
            sf-seed-Users -mail "wcf@test.test" -roles "Administrators,BackendUsers"
        }
    }
}

function sf-auth-basic-getHeaderValue {
    Param($user = "wcf@test.test", $pass = "admin@2")
    $Text = "$($user):$pass"
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $EncodedText = [Convert]::ToBase64String($Bytes)
    "Basic $EncodedText"
}

function sf-auth-protocol {
    param (
        [ValidateSet("OpenId", "SimpleWebToken", "Default")]
        $protocol
    )

    $config = sf-config-open -name "Authentication"
    $root = $config["authenticationConfig"]
    $root.SetAttribute("authenticationProtocol", $protocol)
    sf-config-save -config $config
    sf-iis-appPool-Reset
}