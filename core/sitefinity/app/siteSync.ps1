function sf-siteSync-install {
    Param(
        [switch]$skipSourceControlMapping,
        [switch]$skipSolutionClone
    )

    [SfProject]$source = sf-project-get
    $sourceName = $source.displayName

    # check if project is initialized
    $dbName = sf-db-getNameFromDataConfig
    $dbServer = sql-get-dbs | ? { $_.name -eq $dbName }
    if (!$dbServer) {
        Write-Warning "Not initialized with db. Initializing..."
        sf-app-ensureRunning
    }

    # clone with database clone
    sf-project-clone -skipSourceControlMapping:$skipSourceControlMapping -skipSolutionClone:$skipSolutionClone
    
    # setup the target
    sf-project-rename -newName "$($sourceName)_trg"
    _sitesync-setupTarget
    $siteSyncSuffix = "sitesync-$([Guid]::NewGuid().ToString().Split('-')[0].Substring(0,3))"
    sf-project-tags-add -tagName $siteSyncSuffix
    sf-states-save -stateName $siteSyncSuffix
    $targetUrl = sf-iis-site-getUrl
    
    # setup the source
    sf-project-setCurrent -newContext $source
    sf-project-rename -newName "$($sourceName)_src"
    sf-project-tags-add -tagName $siteSyncSuffix
    _sitesync-setupSource -targetUrl $targetUrl
    sf-states-save -stateName $siteSyncSuffix
}

function sf-siteSync-uninstall {
    param (
        [Parameter(ValueFromPipeline)]
        [SfProject]
        $project,
        [switch]
        $passThruProject
    )
    
    process {
        Run-InFunctionAcceptingProjectFromPipeline {
            param($project)
            sf-serverCode-run "SitefinityWebApp.SfDev.SiteSync" -methodName "Uninstall" > $null
            # TODO remove all counterparts with relevant tags
            sf-project-tags-get | ? { $_ -like "sitesync-*" } | % { sf-project-tags-remove -tagName $_ }
            sf-states-get | ? name -Like "sitesync-*" | sf-states-remove
            $name = $project.displayName.Replace("_src", "").Replace("_trg", "")
            if ($name -ne $project.displayName) {
                sf-project-rename $name
            }
        }
    }
}

function _sitesync-setupTarget {
    # sf-serverCode-run "SitefinityWebApp.SfDev.SiteSync" -methodName "SetupDestination" > $null
    _sitesync-installModule
    sf-seed-Users -mail "sync@test.test" -roles "Administrators,BackendUsers"

    $jsDate = sf-date-convertToJSFormat (Get-Date)
    sf-wcf-invoke -path "Sitefinity/Services/BasicSettings.svc/generic/00000000-0000-0000-0000-000000000000/?itemType=Telerik.Sitefinity.SiteSync.BasicSettings.SiteSyncSettingsContract" -method "PUT" -body "{`"Item`":{`"__type`":`"SiteSyncSettingsContract:#Telerik.Sitefinity.SiteSync.BasicSettings`",`"CurrentServer`":{`"IsEnabledAsTarget`":true,`"MaxServerKey`":100,`"MinServerKey`":0,`"ServerKey`":1},`"ReceivingServers`":[],`"LastModified`":`"\/Date($jsDate)\/`"}}"
}

function _sitesync-setupSource {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $targetUrl
    )

    # sf-serverCode-run "SitefinityWebApp.SfDev.SiteSync" -methodName "SetupSrc" -parameters $targetUrl > $null
    _sitesync-installModule
    $jsDate = sf-date-convertToJSFormat (Get-Date)
    sf-wcf-invoke -path "Sitefinity/Services/BasicSettings.svc/generic/00000000-0000-0000-0000-000000000000/?itemType=Telerik.Sitefinity.SiteSync.BasicSettings.SiteSyncSettingsContract" -method "PUT" -body "{`"Item`":{`"__type`":`"SiteSyncSettingsContract:#Telerik.Sitefinity.SiteSync.BasicSettings`",`"CurrentServer`":{`"IsEnabledAsTarget`":false,`"MaxServerKey`":100,`"MinServerKey`":1,`"ServerKey`":1},`"ReceivingServers`":[{`"ServerId`":null,`"ServerAddress`":`"$targetUrl`",`"UserName`":`"sync@test.test`",`"Password`":`"admin@2`",`"Provider`":`"`",`"MicrositeId`":`"`",`"MicrositeName`":`"`",`"SourceMicrositeName`":`"`"}],`"LastModified`":`"\/Date($jsDate)\/`"}}"
}

function _sitesync-installModule {
    $modules = sf-wcf-invoke -path "Sitefinity/Services/ModulesService/modules?skip=0&take=50" | ConvertFrom-Json
    $siteSync = $modules.Items | ? { $_.ClientId -eq "Synchronization"}
    $type = $siteSync.Type
    if ($siteSync.StartupType -ne 0 -and $siteSync.Status -ne 2) {
        sf-wcf-invoke -path "Sitefinity/Services/ModulesService/modules?operation=0" -method "PUT" -body "{`"ClientId`":`"Synchronization`",`"Description`":`"Use Site Sync to synchronize data between different environments. For example, you can synchronize all of the newly edited news from your work environment with your production server.`",`"ErrorMessage`":`"`",`"IsModuleLicensed`":true,`"IsSystemModule`":false,`"Key`":`"Synchronization`",`"ModuleId`":`"20ff9b05-f217-495d-a1b0-dd747232b0f3`",`"ModuleType`":0,`"Name`":`"Synchronization`",`"ProviderName`":`"`",`"StartupType`":0,`"Status`":0,`"Title`":`"Site Sync`",`"Type`":`"$type`",`"Version`":null}"
    }
}