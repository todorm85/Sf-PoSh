
function _set-errorGroupId {
    Param(
        [System.Collections.ArrayList]$errors,
        [string]$error2check
        )

    if ([string]::IsNullOrEmpty($error2check)) {
        return -1
    }

    $idx = $errors.indexOf($error2check)
    if ($idx -eq -1) {
        $errors.Add($error2check) > $null
        $idx = $errors.Count - 1
    }

    return $idx
}

function _load-testsFromPath {
    Param($path)

    $resultsFiles = _get-allXmls $path

    $allTests = [System.Collections.ArrayList]@()

    forEach($resultsFile in $resultsFiles) {
        $tests = _load-testsFromXml $resultsFile.FullName
        forEach($test in $tests) {
            $allTests.Add($test) > $Null
        }
    }    

    return $allTests
}

function _get-allXmls {
    Param([string]$path)
    
    return get-childitem $path | where {$_.extension -eq ".xml"}
}

function _load-testsFromXml {
    Param(
        $path,
        [switch]$setCategory
        )

    $data = New-Object XML
    $data.Load($path)
    
    $tests = $data.TestResults.testRun.RunnerTestResult | Select-Object -Property FixtureName, TestMethodName, AuthorName, Result, Message

    if ($setCategory) {
        $cat = Get-ChildItem $path | % {$_.BaseName}
        $tests | Add-Member Category $cat
    }

    return $tests
}
