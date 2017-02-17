function sfTest-run-tests {
    . "${PSScriptRoot}\SfTest-runner-config.ps1"
    $sitefinityUrl
    & $cmdTestRunnerPath Run /Url="$($sitefinityUrl)" /RunName="test" /tests="$($tests)" /CategoriesFilter="$($categories)" /UserName="$($username)" /Password="$($pass)" /TraceFilePath="${resultsDirectory}\results.xml" 2>&1
}

function sfTest-run-configuredCategories {

    forEach ($cat in $categories) {
        try {
            Write-Host "$cat started."
    
            sfTest-run-tests -categories $cat

            Write-Host "$cat completed."
        } catch {
            Write-Host "Stopping all runs... Error: " + $_
            break
        }
    }
}

function sfTest-run-configuredTests {

    . "${PSScriptRoot}\SfTest-runner-config.ps1"

    forEach ($test in $tests) {
        try {
            Write-Host "$test started."

            sfTest-run-tests -tests $test

            Write-Host "$test completed."
        } catch {
            Write-Host "Stopping all runs... Error: " + $_
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
        Write-Host "Resetting instance..."
        try {
            _sfTest-reset-appDbp > $resetOutput
        }
        catch {
            $resetOutput
            return            
        }

        Write-Host "Running fixture: $testGroupKey"
        foreach ($test in $testsToRerun[$testGroupKey]) {
            Write-Host "    Running method: $($test.TestMethodName)"
            sfTest-run-tests -tests $test.TestMethodName > $Null
        }
    }
}