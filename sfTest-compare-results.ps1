$localTestResultsPath = "D:\DF-test-results\local-results"
$remoteTestResultsPath = "D:\DF-test-results\df-results"
$traceFileName = "compare-result"
$traceOutputDir = "${Env:userprofile}\Desktop"

function sf-compare-testResultsFolders {

    $localTests = _load-testsFromPath $localTestResultsPath
    $remoteTests = _load-testsFromPath $remoteTestResultsPath

    _compare-tests $localTests $remoteTests
}

function sf-compare-testResultsFiles {
    Param(
        $fileName = "compare-result-files"
        )

    $localTests = _load-testsFromFile "${localTestResultsPath}\${fileName}.xml"
    $remoteTests = _load-testsFromFile "$remoteTestResultsPath\${fileName}.xml"

    _compare-tests $localTests $remoteTests
}

function _load-testsFromPath {
    Param($path)

    $resultsFiles = _get-allXmlResults $path

    $allTests = [System.Collections.ArrayList]@()

    forEach($resultsFile in $resultsFiles) {
        $tests = _load-testsFromFile $resultsFile.FullName
        forEach($test in $tests) {
            $allTests.Add($test) > $Null
        }
    }    

    return $allTests
}

function _get-allXmlResults {
    Param([string]$dirPath)
    
    return get-childitem $dirPath | where {$_.extension -eq ".xml"}
}

function _load-testsFromFile {
    Param(
        $path
        )

    $data = New-Object XML
    $data.Load($path)
    
    $tests = $data.TestResults.testRun.RunnerTestResult | Select-Object -Property FixtureName, TestMethodName, AuthorName, Result, Message

    $cat = Get-ChildItem $path | % {$_.BaseName}
    $tests | Add-Member Category $cat

    return $tests
}

function _compare-tests {
    Param($localTests, $remoteTests )

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

                $localTest.Message -match "^(?<msgLoc>.*)\n   at " > $Null
                $localTestMessage = $matches["msgLoc"]
                $remoteTest.Message -match "^(?<msgRem>.*)\n   at " > $Null
                $remoteTestMessage = $matches["msgRem"]
                $sameMessage = $localTestMessage -eq $remoteTestMessage

                $localErrorGroupId = _get-errorGroupId $localTestMessages, $localTestMessage
                $remoteErrorGroupId = _get-errorGroupId $remoteTestMessages, $remoteTestMessage
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

function _get-errorGroupId {
    Param([System.Collections.ArrayList]$localTestMessages, $localTestMessage ) 

    $locMsgIdx = [array]::IndexOf($localTestMessages, $localTestMessage)
    if ($locMsgIdx -lt 0) {
        $localTestMessages.Add($localTestMessage)
        return $localTestMessages.Count - 1
    } else {
        return $locMsgIdx
    }
}