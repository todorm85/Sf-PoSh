Import-Module "WebAdministration"

$cmdTestRunnerPath = "D:\Tools\Telerik.WebTestRunner\Telerik.WebTestRunner.Cmd\bin\Debug\Telerik.WebTestRunner.Cmd.exe"
$TfisTokenEndpointUrl = "https://uatidentity.telerik.com/v2/oauth/telerik/token"
$TfisTokenEndpointBasicAuth = "dXJpJTNBaW50ZWdyYXRpb24udGVzdHM6NDcwNzE5MTU0NjZmYTBlNWYwNmRlYWQ3NGY4MTFkMzE="
$accounId = "1495b382-c205-4ae4-b0e1-204689558b24"
$username = "tmitskov@progress.com"
$pass = "admin@2"
$sitefinityUrl = "https://ft4qp557kaz7u0bu.sites.testtap.telerik.com"
$dbBackupId = "bb465e55-d567-477a-9b61-36127a278def"
$resultsDirectory = "D:\DF-test-results\local-results"

$categories = @( 
    "Modules",
    "ModuleBuilder",
    "Data",
    "Events",
    "Core",
    "InlineEditing",
    "Connectors",
    "OpenAccess",
    "Multisite",
    "MVC",
    "ContentApi",
    "SDK",
    "Services",
    "Publishing",
    "Lightning",
    "Audit",
    "Ssl",
    "Personalization",
    "Permissions",
    "RelatedData",
    "PageTemplateThumbnails",
    "PageTemplates",
    "Ecommerce",
    "ZoneEditor",
    "MultisiteTaxonomy",
    "Workflow",
    "RecycleBin",
    "RevisionHistory",
    "Translations",
    "TranslationsIntegrations",
    "Performance",
    "PerformanceTips",
    "WebServices1",
    "WebServices2",
    "Diagnostics",
    "NotificationService", 
    "Libraries", 
    "DigitalBusinessPlatform", 
    "CacheInvalidation", 
    "ImportExportBlogsContent", 
    "ImportExportContentBlock", 
    "ImportExportCustomFlatTaxonomies", 
    "ImportExportCustomHierarchicalTaxonomies", 
    "ImportExportDocumentsContent", 
    "ImportExportDynamicContent", 
    "ImportExportEventContent", 
    "ImportExportImagesContent", 
    "ImportExportListsContent", 
    "ImportExportMediaContent", 
    "ImportExportMultisiteContent", 
    "ImportExportNewsContent", 
    "ImportExportPagesContent", 
    "ImportExportPageTemplatesContent", 
    "ImportExportVideosContent", 
    "ImportExportWebServices", 
    "PackagingBlogsStructure", 
    "PackagingDynamicStructure", 
    "PackagingEventsStructure", 
    "PackagingForumsStructure", 
    "PackagingLibrariesStructure", 
    "PackagingListsStructure", 
    "PackagingNewsStructure", 
    "PackagingPagesStructure", 
    "PackagingLogger", 
    "Search", 
    "Sitemap", 
    "MultiSiteService", 
    "RandomGuid", 
    "ConfigurationDifferentialSave"
)

function dfTests-run-all {
    Param([string]$url="http://localhost:4080")

    if ($url) {
        $sitefinityUrl = $url
    }

    forEach ($cat in $categories) {
        try {
            Write-Host "$cat started."
            dfTests-run-dfTest $cat
            Write-Host "$cat completed."
        } catch {
            Write-Host "Stopping all runs... Error: " + $_
            break
        }
    }
}

function dfTests-run-dfTest {
    Param(
        [string]$category,
        [switch]$restoreDb
        )

    if ($restoreDb) {
        try {
            _restore-db
        } catch {
            throw "Error restoring database." + $_
        }
    }
    
    & $cmdTestRunnerPath Run /Url=$sitefinityUrl /RunName=test  /CategoriesFilter=$category /TfisTokenEndpointUrl=$TfisTokenEndpointUrl /TfisTokenEndpointBasicAuth=$TfisTokenEndpointBasicAuth /UserName=$username /Password=$pass /TraceFilePath="${resultsDirectory}\${category}.xml" 2>&1
}

function _restore-db {
    $token = _get-token

    $url = "https://testtap.telerik.com/sitefactory/api/${accounId}/restore-operations"
    $body = "{""environmentType"":""staging"",""backupId"":""${dbBackupId}""}"
    $contentType = "application/json"
    $headers = @{ Authorization = "Bearer $token" }

    $response = Invoke-WebRequest $url -TimeoutSec 1600 -body $body -Method Post -Headers $headers -ContentType $contentType

    if($response.StatusCode -eq 202)
    {
        Write-Host "Database is restoring..."
    } else {
        throw "Not accepted restore of Database on DF"
    }

    $url = "https://testtap.telerik.com/sitefactory/api/${accounId}/actions"
    $headers = @{ Authorization = "Bearer $token" }

    $status = ""
    while ($status -ne "Completed" -and $status -ne "Failed") {
        try {
            $response = Invoke-WebRequest $url -TimeoutSec 1600 -Headers $headers
            $jsonContent = ConvertFrom-JSON $response.Content
            $status = $jsonContent[0].status
            Start-Sleep -s 2
        } catch {
            throw "Error sending request to DF."
        }
    }

    if ($status -eq "Failed") {
        throw "Failed restore of database"
    }
}

function _get-token {
    $body = "{""grant_type"":""password"",""username"":""${username}"",""password"":""${pass}""}"
    $contentType = "application/json"
    $headers = @{ Authorization = "Basic dXJpJTNBaW50ZWdyYXRpb24udGVzdHM6NDcwNzE5MTU0NjZmYTBlNWYwNmRlYWQ3NGY4MTFkMzE=" }

    $response = Invoke-WebRequest $TfisTokenEndpointUrl -TimeoutSec 1600 -body $body -Method Post -Headers $headers -ContentType $contentType
    $jsonContent = ConvertFrom-JSON $response.Content
    return $jsonContent.access_token;
}