
. "${PSScriptRoot}\sf-tests-runner-config.ps1"

function sfTest-run-configuredCategories {
    Param(
        [switch]$restoreDfDb
        )

    forEach ($cat in $categories) {
        try {
            Write-Verbose "$cat started."
    
            if ($restoreDfDb) {
                try {
                    _df-restore-db
                } catch {
                    throw "Error restoring database." + $_
                }
            }

            sfTest-run-tests -categories $cat

            Write-Verbose "$cat completed."
        } catch {
            Write-Verbose "Stopping all runs... Error: " + $_
            break
        }
    }
}

function sfTest-run-configuredTests {

    forEach ($test in $tests) {
        try {
            Write-Verbose "$test started."

            sfTest-run-tests -tests $test

            Write-Verbose "$test completed."
        } catch {
            Write-Verbose "Stopping all runs... Error: " + $_
            break
        }
    }
}

function sfTest-rerun-tests () {
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
        Write-Verbose "Resetting instance..."
        try {
            _sfTest-reset-appDbp > $resetOutput
        }
        catch {
            $resetOutput
            return            
        }

        Write-Verbose "Running fixture: $testGroupKey"
        foreach ($test in $testsToRerun[$testGroupKey]) {
            Write-Verbose "    Running method: $($test.TestMethodName)"
            sfTest-run-tests -tests $test.TestMethodName > $Null
        }
    }
}

function sfTest-run-tests {
    Param(
        [string]$categories = "",
        [string]$tests = ""
        )
    
    & $cmdTestRunnerPath Run /Url=$sitefinityUrl /RunName=test /tests=$tests /CategoriesFilter=$categories /TfisTokenEndpointUrl=$TfisTokenEndpointUrl /TfisTokenEndpointBasicAuth=$TfisTokenEndpointBasicAuth /UserName=$username /Password=$pass /TraceFilePath="${resultsDirectory}\results.xml" 2>&1
}

function _sfTest-reset-appDbp () {
    sf-reset-appDbp
    sf-set-storageMode Auto Default
    _sfTest-setup-multilingual
    sf-set-storageMode Auto ReadOnlyConfigFile
}

function _sfTest-setup-multilingual () {
    sfTest-run-tests -tests "DummyTest"
}

function _df-restore-db {
    Import-Module "WebAdministration"
    
    $token = _df-get-token

    $url = "https://testtap.telerik.com/sitefactory/api/${accounId}/restore-operations"
    $body = "{""environmentType"":""staging"",""backupId"":""${dbBackupId}""}"
    $contentType = "application/json"
    $headers = @{ Authorization = "Bearer $token" }

    $response = Invoke-WebRequest $url -TimeoutSec 1600 -body $body -Method Post -Headers $headers -ContentType $contentType

    if($response.StatusCode -eq 202)
    {
        Write-Verbose "Database is restoring..."
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