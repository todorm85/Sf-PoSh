Import-Module "WebAdministration"
. "${PSScriptRoot}\sfTests-runner-config.ps1"

function sfTests-run-allCategories {
    Param(
        [string]$url = $sitefinityUrl,
        [switch]$restoreDfDb
        )

    forEach ($cat in $categories) {
        try {
            Write-Host "$cat started."
    
            if ($restoreDfDb) {
                try {
                    _df-restore-db
                } catch {
                    throw "Error restoring database." + $_
                }
            }

            _sfTests-run-tests -categories $cat

            Write-Host "$cat completed."
        } catch {
            Write-Host "Stopping all runs... Error: " + $_
            break
        }
    }
}

function sfTests-run-allTests {
    Param(
        [string]$url = $sitefinityUrl
        )

    forEach ($test in $tests) {
        try {
            Write-Host "$test started."

            _sfTests-run-tests -tests $test

            Write-Host "$test completed."
        } catch {
            Write-Host "Stopping all runs... Error: " + $_
            break
        }
    }
}

function _sfTests-run-tests {
    Param(
        [string]$categories = "",
        [string]$tests = ""
        )
    
    & $cmdTestRunnerPath Run /Url=$sitefinityUrl /RunName=test /tests=$tests /CategoriesFilter=$categories /TfisTokenEndpointUrl=$TfisTokenEndpointUrl /TfisTokenEndpointBasicAuth=$TfisTokenEndpointBasicAuth /UserName=$username /Password=$pass /TraceFilePath="${resultsDirectory}\results.xml" 2>&1
}

function _df-restore-db {
    $token = _df-get-token

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

function _df-get-token {
    $body = "{""grant_type"":""password"",""username"":""${username}"",""password"":""${pass}""}"
    $contentType = "application/json"
    $headers = @{ Authorization = "Basic dXJpJTNBaW50ZWdyYXRpb24udGVzdHM6NDcwNzE5MTU0NjZmYTBlNWYwNmRlYWQ3NGY4MTFkMzE=" }

    $response = Invoke-WebRequest $TfisTokenEndpointUrl -TimeoutSec 1600 -body $body -Method Post -Headers $headers -ContentType $contentType
    $jsonContent = ConvertFrom-JSON $response.Content
    return $jsonContent.access_token;
}