function sf-auth-ldap {
    Param(
        [switch]$enable,
        [switch]$disable
    )

    $config = sf-config-open -name "Security"
    $root = $config["securityConfig"]
    if ($enable) {
        $ldapConnection = Xml-GetOrCreateElementPath $root -elementPath "//LdapConnections/connections/LdapConnection[@name=DefaultLdapConnection]"
        $ldapConnection.SetAttribute("serverName", "NTSOFDCBED02.bedford.progress.com")
        $ldapConnection.SetAttribute("connectionDomain", "bedford.progress.com")
        $ldapConnection.SetAttribute("connectionUsername", "SitefinityLdapReader")
        $ldapConnection.SetAttribute("connectionPassword", "ldlk5tZJ9xbjAP9U")
        $ldapConnection.SetAttribute("usersDN", "dc=bedford,dc=progress,dc=com")
        $ldapConnection.SetAttribute("rolesDns", "dc=bedford,dc=progress,dc=com")

        $ldapUsers = xml-getOrCreateElementPath $root -elementPath "//membershipProviders/add[@name=LdapUsers]"
        $ldapUsers.SetAttribute("enabled", "True")

        $roleProvider = xml-getOrCreateElementPath $root -elementPath "//roleProviders/add[@name=LdapRoles]"
        $roleProvider.SetAttribute("enabled", "True")

        $administrativeRoles = xml-getOrCreateElementPath $root -elementPath "//administrativeRoles/role[@roleName=SitefinityToolingTeam]"
        $administrativeRoles.SetAttribute("roleProvider", "LdapRoles")
    }

    if ($disable) {
        $ldapUsers = xml-getOrCreateElementPath $root -elementPath "//membershipProviders/add[@name=LdapUsers]"
        $ldapUsers.SetAttribute("enabled", "False")

        $roleProvider = xml-getOrCreateElementPath $root -elementPath "//roleProviders/add[@name=LdapRoles]"
        $roleProvider.SetAttribute("enabled", "False")
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

        $connectionString = xml-getOrCreateElementPath $root -elementPath "//connectionStrings/add[@name=AspNetMembership]"
        $connectionString.SetAttribute("connectionString", "data source=.;UID=sa;PWD=admin@2admin@2;initial catalog=$dbName")

        $roleManager = xml-getOrCreateElementPath $root -elementPath "//system.web/roleManager"
        $roleManager.SetAttribute("enabled", "true")

        $roleProvider = xml-getOrCreateElementPath $roleManager -elementPath "//providers/clear"
        $roleProvider = xml-getOrCreateElementPath $roleManager -elementPath "//providers/add[@name=AspNetSqlRoleProvider]"
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
        $googleEntry = xml-getOrCreateElementPath $root -elementPath "//securityTokenServiceSettings/authenticationProviders/add[@name=Google]"
        $googleEntry.SetAttribute("appId", "771822853545-92c5hongqfb80nh927ejv6hajpceorbs.apps.googleusercontent.com")
        $googleEntry.SetAttribute("appSecret", "Sn8tDo28EIAL-oVxOy9euYp0")
        $googleEntry.SetAttribute("enabled", "True")
        $googleEntry.SetAttribute("autoAssignedRoles", "Users, BackendUsers, Administrators")

    }
    
    if($disable) {
        $googleEntry = xml-getOrCreateElementPath $root -elementPath "//securityTokenServiceSettings/authenticationProviders/add[@name=Google]"
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
    $relyingPartySettings = xml-getOrCreateElementPath -elementPath "//relyingPartySettings" -root $root
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