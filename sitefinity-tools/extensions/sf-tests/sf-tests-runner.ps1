Import-Module "WebAdministration"
. "${PSScriptRoot}\sf-tests-runner-config.ps1"
. "${PSScriptRoot}\sf-tests-common.ps1"

function sfTests-run-configuredCategories {
    Param(
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

            sfTests-run-tests -categories $cat

            Write-Host "$cat completed."
        } catch {
            Write-Host "Stopping all runs... Error: " + $_
            break
        }
    }
}

function sfTests-run-configuredTests {

    forEach ($test in $tests) {
        try {
            Write-Host "$test started."

            sfTests-run-tests -tests $test

            Write-Host "$test completed."
        } catch {
            Write-Host "Stopping all runs... Error: " + $_
            break
        }
    }
}

function sfTests-rerun-tests () {
    Param($xmlPath = "D:\sitefinities\IntegrationTests01\test-results\tests.xml")

    $tests = _load-testsFromXml $xmlPath
    $testsToRerun = @{}
    foreach ($test in $tests) {
        if ($test.Result -eq "Failed") {
            if (-not $testsToRerun[$test.FixtureName]) {
                $testsToRerun[$test.FixtureName] = [System.Collections.ArrayList]@()
            }

            $testsToRerun[$test.FixtureName].Add($test) > $Null
        }
    }

    foreach ($testGroupKey in $testsToRerun.Keys) {
        Write-Host "Resetting instance..."
        try {
            sfTests-reset-appDbp > $resetOutput
        }
        catch {
            $resetOutput
            return            
        }

        Write-Host "Running fixture: $testGroupKey"
        foreach ($test in $testsToRerun[$testGroupKey]) {
            Write-Host "    Running method: $($test.TestMethodName)"
            sfTests-run-tests -tests $test.TestMethodName > $Null
        }
    }
}

function sfTests-run-tests {
    Param(
        [string]$categories = "",
        [string]$tests = ""
        )
    
    & $cmdTestRunnerPath Run /Url=$sitefinityUrl /RunName=test /tests=$tests /CategoriesFilter=$categories /TfisTokenEndpointUrl=$TfisTokenEndpointUrl /TfisTokenEndpointBasicAuth=$TfisTokenEndpointBasicAuth /UserName=$username /Password=$pass /TraceFilePath="${resultsDirectory}\results.xml" 2>&1
}

function sfTests-reset-appDbp () {
    sf-reset-appDbp
    sf-set-storageMode Auto Default
    sfTests-setup-multilingual
    sf-set-storageMode Auto ReadOnlyConfigFile
}

function sfTests-setup-multilingual () {
    sfTests-run-tests -tests "DummyTest"
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