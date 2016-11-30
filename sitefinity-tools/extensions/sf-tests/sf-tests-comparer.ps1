. "${PSScriptRoot}\sf-tests-common.ps1"

$localTestResultsPath = "D:\DF-test-results\local-results"
$remoteTestResultsPath = "D:\DF-test-results\df-results"
$traceOutputDir = "${Env:userprofile}\Desktop"

function sfTests-compare-testResultsFoldersByCategory {

    $locResFiles = _get-allXmls $localTestResultsPath

    forEach($resFile in $locResFiles) {
        
        Write-Host "Comapring $($resFile.BaseName)..."

        $localTests = _load-testsFromXml $resFile.FullName -setCategory
        $remoteTests = _load-testsFromXml "${remoteTestResultsPath}\$($resFile.BaseName).xml" -setCategory

        _compare-tests $localTests $remoteTests $resFile.BaseName

        Write-Host "Done comapring $($resFile.BaseName)."
    }
}


function sfTests-compare-testResultsFolders {

    $localTests = _load-testsFromPath $localTestResultsPath
    $remoteTests = _load-testsFromPath $remoteTestResultsPath

    _compare-tests $localTests $remoteTests
}

function sfTests-compare-testResultsFiles {
    Param(
        $fileName = "Core"
        )

    $localTests = _load-testsFromXml "${localTestResultsPath}\${fileName}.xml"
    $remoteTests = _load-testsFromXml "${remoteTestResultsPath}\${fileName}.xml"

    _compare-tests $localTests $remoteTests
}

function _compare-tests {
    Param($localTests, $remoteTests, $traceFileName = "compare-result")

    $failedTests = [System.Collections.ArrayList]@()
    $localTestMessages = [System.Collections.ArrayList]@()
    $remoteTestMessages = [System.Collections.ArrayList]@()
    foreach($localTest in $localTests) {
        # if failed
        if ($localTest.Result -eq "Failed") {
            # find RemoteTest by FixtureName and TestMethodName
            $remoteTest = $remoteTests | Where-Object {$_.FixtureName -eq $localTest.FixtureName -and $_.TestMethodName -eq $localTest.TestMethodName }
            if ($remoteTest -ne $Null) {
                $remoteResult = $remoteTest.Result
                $remoteMessage = $remoteTest.Message
                $bothFailFlag = $localTest.Result -eq $remoteTest.Result

                $localTest.Message -match "^(?<msgLoc>(.|\n)*?)\n   at " > $Null
                $localTestMessage = $matches["msgLoc"]
                $remoteTest.Message -match "^(?<msgRem>(.|\n)*?)\n   at " > $Null
                $remoteTestMessage = $matches["msgRem"]
                $sameMessage = $localTestMessage -eq $remoteTestMessage

                $localErrorGroupId = _set-errorGroupId $localTestMessages $localTestMessage
                $remoteErrorGroupId = _set-errorGroupId $remoteTestMessages $remoteTestMessage
            } else {
                $remoteResult = 'Null'
                $remoteMessage = 'Null'
                $bothFailFlag = 'Null'
                $sameMessage = 'Null'
            }

            # add remote results - RemoteResult, RemoteMessage, BothFailFlag
            $localTest | Add-Member RemoteResult $remoteResult
            $localTest | Add-Member RemoteMessage $remoteMessage
            $localTest | Add-Member BothFailFlag $bothFailFlag
            $localTest | Add-Member SameMessage $sameMessage
            $localTest | Add-Member LocalErrorGroup $localErrorGroupId
            $localTest | Add-Member RemoteErrorGroup $remoteErrorGroupId

            # add to $failedTests
            $failedTests.Add($localTest) > $Null
        }
    }

    # add all remoteTests that do not have locals
    foreach($remoteTest in $remoteTests) {
        $localTest = $localTests | Where-Object {$_.FixtureName -eq $remoteTest.FixtureName -and $_.TestMethodName -eq $remoteTest.TestMethodName }
        if ($localTest -ne $Null) {
            continue;
        }

        $remoteResult = $remoteTest.Result
        $remoteMessage = $remoteTest.Message
        $bothFailFlag = 'Null'

        $remoteTest.Result = 'Null'
        $remoteTest.Message = 'Null'

        $remoteTest | Add-Member RemoteResult $remoteResult
        $remoteTest | Add-Member RemoteMessage $remoteMessage
        $remoteTest | Add-Member BothFailFlag $bothFailFlag
        $localTest | Add-Member SameMessage $sameMessage
        $localTest | Add-Member LocalErrorGroup $localErrorGroupId
        $localTest | Add-Member RemoteErrorGroup $remoteErrorGroupId

        $failedTests.Add($remoteTest) > $Null
    }

    $failedTests | Export-Excel "${traceOutputDir}\${traceFileName}.xlsx"
}

#sfTests-compare-testResultsFiles Connectors
# sfTests-compare-testResultsFolders